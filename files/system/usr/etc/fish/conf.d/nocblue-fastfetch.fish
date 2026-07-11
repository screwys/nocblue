function fastfetch --wraps fastfetch --description "Render fastfetch after it completes"
    command fastfetch $argv | command cat
    return $pipestatus[1]
end
