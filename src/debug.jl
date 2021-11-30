const DEBUG_FLAG_NAME = "debug"
const DEBUG_FLAG_ENABLED_VALUE = "enabled"

function get_debug_flag(value = @load_preference(DEBUG_FLAG_NAME))
    value in (DEBUG_FLAG_ENABLED_VALUE, nothing) && return value == DEBUG_FLAG_ENABLED_VALUE
    @error "Invalid value `$( repr( value ) )` for preference `$DEBUG_FLAG_NAME`."
    return false
end

enable_debug() = @set_preferences!(DEBUG_FLAG_NAME => DEBUG_FLAG_ENABLED_VALUE)
disable_debug() = @delete_preferences!(DEBUG_FLAG_NAME)

const DEBUG_ENABLED = get_debug_flag()

macro ifdebug(ex)
    if DEBUG_ENABLED
        esc(ex)
    end
end
