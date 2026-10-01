#!/usr/bin/python3
"""Give programs launched by Nix the host's ordinary execution context."""

import sys
from collections import defaultdict

import setools


SOURCE = "unconfined_t"
NIX = "nocblue_nix_t"
ENTRY = "nocblue_nix_exec_t"
PLAIN = "nocblue_nix_plain_exec_file_type"


def condition(rule):
    try:
        expression = rule.conditional.expression()
        true_branch = rule.conditional_block
    except setools.exception.RuleNotConditional:
        return None
    operators = {"!": ("not", 1), "&&": ("and", 2), "||": ("or", 2),
                 "^": ("xor", 2), "==": ("eq", 2), "!=": ("neq", 2)}
    stack = []
    for item in expression:
        symbol = str(item)
        if symbol in operators:
            operator, count = operators[symbol]
            args, stack = stack[-count:], stack[:-count]
            stack.append(f"({operator} {' '.join(args)})")
        else:
            stack.append(symbol)
    [result] = stack
    return result if true_branch else f"(not {result})"


def either(expressions):
    result, *rest = sorted(set(expressions))
    for expression in rest:
        result = f"(or {result} {expression})"
    return result


def generate(policy):
    statements = set()
    permissions = defaultdict(set)

    def statement(text, guard=None):
        if guard is not None:
            text = f"(booleanif {guard} (true {text}))"
        statements.add(text)

    transitions = defaultdict(list)
    query = setools.TERuleQuery(policy, ruletype=["type_transition"],
                               source=SOURCE, tclass=["process"])
    for rule in query.results():
        for target in rule.target.expand():
            if str(target) != ENTRY:
                transitions[str(target)].append((str(rule.default), condition(rule)))

    entries = set(transitions)
    destinations = {SOURCE} | {dest for rules in transitions.values() for dest, _ in rules}
    excluded = " ".join(sorted(entries | {ENTRY}))
    statement(f"(typeattribute {PLAIN})")
    statement(f"(typeattributeset {PLAIN} (and (file_type) (not ({excluded}))))")
    statement(f"(typetransition {NIX} {PLAIN} process {SOURCE})")
    permissions[None, NIX, PLAIN, "file"].update({"getattr", "open", "read", "execute", "map"})
    permissions[None, SOURCE, PLAIN, "file"].add("entrypoint")
    # The normal no-transition case becomes a return from Nix's domain.
    permissions[None, NIX, SOURCE, "process2"].update({"nnp_transition", "nosuid_transition"})

    for entry, rules in transitions.items():
        for destination, guard in rules:
            statement(f"(typetransition {NIX} {entry} process {destination})", guard)
        if all(guard is not None for _, guard in rules):
            fallback = f"(not {either(guard for _, guard in rules)})"
            statement(f"(typetransition {NIX} {entry} process {SOURCE})", fallback)
            permissions[fallback, SOURCE, entry, "file"].add("entrypoint")

    forward_masks = {
        "file": {"getattr", "open", "read", "execute", "map"},
        "process": {"transition", "noatsecure", "siginh", "rlimitinh", "signal", "sigkill", "sigstop", "signull"},
        "process2": {"nnp_transition", "nosuid_transition"},
    }
    query = setools.TERuleQuery(policy, ruletype=["allow"], source=SOURCE,
                               tclass=list(forward_masks))
    for rule in query.results():
        tclass = str(rule.tclass)
        allowed = set(rule.perms) & forward_masks[tclass]
        if not allowed:
            continue
        wanted = entries if tclass == "file" else destinations
        targets = {str(target) for target in rule.target.expand()} & wanted
        for target in targets:
            permissions[condition(rule), NIX, target, tclass].update(allowed)

    inherited_masks = {
        "fd": {"use"},
        "fifo_file": {"getattr", "open", "read", "write", "append", "ioctl", "lock"},
        "process": {"sigchld", "signal", "sigkill", "sigstop", "signull"},
    }
    query = setools.TERuleQuery(policy, ruletype=["allow"], target=SOURCE,
                               tclass=list(inherited_masks))
    for rule in query.results():
        tclass = str(rule.tclass)
        allowed = set(rule.perms) & inherited_masks[tclass]
        if not allowed:
            continue
        sources = {str(source) for source in rule.source.expand()} & destinations
        for source in sources:
            permissions[condition(rule), source, NIX, tclass].update(allowed)

    for (guard, source, target, tclass), allowed in permissions.items():
        statement(f"(allow {source} {target} ({tclass} ({' '.join(sorted(allowed))})))", guard)

    return ";; Generated from the image's compiled SELinux policy.\n" + "\n".join(sorted(statements)) + "\n"


if __name__ == "__main__":
    [policy_path] = sys.argv[1:]
    sys.stdout.write(generate(setools.SELinuxPolicy(policy_path)))
