if test -x /usr/bin/nocblue-codex
    function codex --wraps codex --description 'Run Codex with the nocblue sandbox wrapper'
        command /usr/bin/nocblue-codex $argv
    end
end
