-- intarsia reads this from %USERPROFILE%\.config\intarsia\config.lua. Every key is required. How the bar looks lives in
-- style.css beside it.
return {
    bar = {
        edge = "top", -- top, bottom, left or right
        -- top: above other windows, lowered while a fullscreen app runs. bottom: other windows can cover it.
        layer = "bottom",
        -- reserve: the monitor's work area leaves the bar out, so maximized windows stop at it. share: the work area
        -- keeps the bar's strip, as for a plain window, so the window manager's gap has to make room for it.
        space = "share",
        thickness = 54, -- DIPs, scaled by each monitor's DPI
    },

    -- glazewm: workspaces and focus over GlazeWM's IPC, retried while GlazeWM is down
    -- windows: no window manager, windows and focus come from Windows itself (no workspaces, windows, binding_mode or
    -- tiling_direction module)
    window_manager = "glazewm",

    -- The lists show modules by the names defined in modules below, left to right. A name in a list that modules
    -- does not define, or a module no list or group shows, is an error. style.css styles a module by its name, as
    -- #date.
    modules_left = { "workspaces", "divider", "apps", "divider_date", "date" },
    modules_center = {},
    modules_right = { "tray", "ziti", "layout", "mode", "tiling", "net", "cpu", "memory", "volume", "mic", "battery" },

    -- A layout replaces the three lists above on a bar whose monitor is at least min_length DIPs long along the bar's
    -- edge (its width for a top or bottom bar, pixels divided by the scale). The last layout a monitor reaches wins, so
    -- each min_length must be greater than the one before. {} shows the lists above everywhere.
    layouts = {
        -- Wider than 1920 DIPs, the date moves to the center.
        {
            min_length = 1921,
            modules_left = { "workspaces", "divider", "apps" },
            modules_center = { "date" },
            modules_right = { "tray", "ziti", "layout", "mode", "tiling", "net", "cpu", "memory", "volume", "mic", "battery" },
        },
    },

    -- Each module has a name you choose and a type: clock, window, workspaces, windows, binding_mode,
    -- tiling_direction, divider, cpu, memory, audio, network, battery, tray, custom, counter or group. One type can
    -- appear under several names with different settings, such as a second clock with its own format.
    --
    -- clock, window, cpu, memory, audio, network, battery, custom and counter take optional on_click, on_right_click,
    -- on_middle_click, on_scroll_up and on_scroll_down actions. { program, arguments... } starts a program: it must be an .exe (absolute, or found on PATH when the
    -- config loads), and it starts without a shell, so arguments reach it exactly as written.
    -- { window_manager = "focus --next-workspace" } sends the window manager a command in its own syntax instead,
    -- without starting a process (glazewm only). { menu = { command = {...}, timeout = 5, on_select = {...} } } opens a
    -- menu of what command prints, as {"items":[{"id":"work","text":"Work","active":true,"tooltip":"..."}]} with
    -- active and tooltip optional and {"separator":true} a blank line between entries. An entry's tooltip shows under
    -- it while the cursor rests on it, and picking an entry runs on_select with the entry's id as its last argument.
    -- An id may not start with - or /.
    --
    -- They also take an optional tooltip: a second format for the same value, shown while the cursor rests on the
    -- module. The workspaces module shows why the window manager is disconnected, with no key needed.
    modules = {
        -- One item per workspace on this monitor: .focused, .occupied (has windows) or .empty. Click one to focus it.
        workspaces = { type = "workspaces" },
        -- A line between modules, sized by width and height in style.css. Each place a line appears is its own module.
        divider = { type = "divider" },
        divider_date = { type = "divider" },
        -- One item per window on the displayed workspace, .focused for the focused one. Click one to focus it.
        apps = { type = "windows" },
        -- One item per active binding mode, nothing while none is active.
        mode = { type = "binding_mode" },
        -- The focused container's tiling direction, drawn as an icon. Click to flip it.
        tiling = { type = "tiling_direction", horizontal = "⇄", vertical = "⇵" },
        date = {
            type = "clock",
            format = "{time:%a %d %b %Y, %H:%M}", -- {time} takes a std::format chrono spec
            tooltip = "{time:%A %d %B %Y, %H:%M:%S}",
            icon = "\u{F1441}",
            interval = 60, -- seconds between redraws, aligned to the clock
        },
        cpu = {
            type = "cpu",
            format = "{usage}%", -- {usage} is a whole percent
            -- {ghz} is the current clock speed as a double, {max_core} the busiest logical processor as a whole percent,
            -- and {cores} every logical processor's usage, four to a line
            tooltip = "Speed {ghz:.2f} GHz\n{cores}",
            icon = "\u{F4BC}",
            interval = 1,
            on_click = { "C:\\Windows\\System32\\Taskmgr.exe" },
        },
        memory = {
            type = "memory",
            format = "{used:.1f} GB", -- {used} is gibibytes in use, as a double
            -- {total}, {available}, {cached}, {committed} and {commit_limit} are gibibytes too, {percent} the share in use
            tooltip = "{used:.1f} of {total:.0f} GB ({percent}%)\nCached {cached:.1f} GB\nCommitted {committed:.1f} of {commit_limit:.0f} GB",
            icon = "\u{EFC5}",
            interval = 1,
            on_click = { "C:\\Windows\\System32\\resmon.exe" },
        },
        -- The interface the internet is reached through, sampled every second. Formats and the tooltip can use {ssid},
        -- {signal} (a percent), {ip}, {interface}, {down} and {up} (rates such as "1.2 MB/s"), and a name can take a
        -- std::format spec, as {signal:>3}. An empty format shows the icon alone. format_ethernet covers every link that
        -- is not Wi-Fi. Windows 11 hides the network's name and signal from apps without location access
        -- (Settings > Privacy & security > Location), and {ssid} is then empty.
        net = {
            type = "network",
            format_wifi = "",
            format_ethernet = "",
            format_disconnected = "",
            -- Weakest signal to strongest, the range split evenly between them.
            icons_wifi = { "\u{F092F}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}" },
            icon_ethernet = "\u{F0200}",
            icon_disconnected = "\u{F092E}",
            tooltip = "{interface} {ssid} {signal}%\n{ip}\n↓ {down}  ↑ {up}",
            on_click = { "C:\\Windows\\explorer.exe", "ms-settings:network-status" },
        },
        -- The default output (speakers) or input (microphone) device's volume, by flow, following device switches.
        -- Click toggles mute, scroll changes the volume by step percent, unless on_click or on_scroll_up and
        -- on_scroll_down replace them. The formats and tooltip can use {volume} (a whole percent) and {device} (its
        -- name). Shows nothing while there is no device of its flow.
        volume = {
            type = "audio",
            flow = "output",
            format = "{volume}%",
            format_muted = "muted",
            icon = "\u{F057E}",
            icon_muted = "\u{F0581}",
            step = 5,
            tooltip = "{device}",
        },
        mic = {
            type = "audio",
            flow = "input",
            format = "{volume}%",
            format_muted = "muted",
            icon = "\u{F036C}",
            icon_muted = "\u{F036D}",
            step = 5,
            tooltip = "{device}",
        },
        -- The batteries taken together, sampled when Windows reports a change of charge or power source. The formats and
        -- tooltip can use {capacity} (a whole percent), {time} (hours and minutes left on battery, as "1:05", empty
        -- until Windows has an estimate) and {health} (full charge capacity against design capacity, a whole percent,
        -- empty when the battery does not report it). format_plugged is on external power and not charging: full, or
        -- held by a charge limit. Shows nothing on a machine with no battery.
        battery = {
            type = "battery",
            format_discharging = "{capacity}%",
            format_charging = "{capacity}%",
            format_plugged = "{capacity}%",
            -- Emptiest to fullest while discharging, the range split evenly between them.
            icons = { "\u{F008E}", "\u{F007C}", "\u{F007E}", "\u{F0081}", "\u{F0079}" },
            icon_charging = "\u{F0084}",
            icon_plugged = "\u{F06A5}",
            -- Discharging at or under these percents draws the module in its .warning, then .critical, colors.
            warning_at = 40,
            critical_at = 20,
            tooltip = "{capacity}% {time}\nHealth {health}%",
            on_click = { "C:\\Windows\\explorer.exe", "ms-settings:batterysaver" },
        },
        -- The notification area: every app's tray icons in the order the apps added them, folded away behind a
        -- toggle showing icon until it is clicked. Click an icon for its app's window, right click it for its menu.
        -- How it unfolds and how the toggle turns is style.css's. While a tray module shows, the bar receives the
        -- icons in the taskbar's place and passes each on to it, so the taskbar still has them all once the bar exits.
        tray = { type = "tray", icon = "\u{F054}" },
        -- Open OpenZiti and NetFoundry PRs and issues: the count, each section's count in the tooltip, and a click opens
        -- a menu of them, where picking one opens its page and a section's header opens its search. Each count also
        -- writes the menu to a file, so opening it only reads that. GitHub allows 10 unauthenticated searches a minute,
        -- and each count takes three.
        ziti = {
            type = "custom",
            command = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoProfile", "-NonInteractive", "-Command",
                        [[& "$HOME\dev\windows-dev\intarsia\ziti-github.ps1"]] },
            run = "interval",
            timeout = 45,
            output = "json",
            classes = {},
            format = "{text}",
            icon = "\u{F02A4}",
            interval = 120,
            on_click = { menu = {
                command = { "C:\\Windows\\System32\\cmd.exe", "/d", "/c", "type", [[%LOCALAPPDATA%\intarsia\ziti-menu.json]] },
                timeout = 5,
                on_select = { "C:\\Windows\\explorer.exe" },
            } },
        },
        -- A group folds its members away behind its icon, and a click on the icon unfolds them after it. It starts
        -- folded. Each member is a module of its own, with its own style, tooltip and actions, that no list and no
        -- other group shows, and none is a group. How it unfolds and how the icon turns is style.css's, as for the tray.
        layout = {
            type = "group",
            icon = "\u{F037A}",
            modules = { "layout_single", "layout_dual" }, -- in the order they unfold
        },
        -- Links the GlazeWM config for one or two monitors. The command only prints the label, so it runs once an hour.
        -- The click runs switch-layout.ps1, which relinks only GlazeWM's config: setup-configs.ps1 would also relink
        -- this directory under the bar.
        layout_single = {
            type = "custom",
            command = { "C:\\Windows\\System32\\cmd.exe", "/d", "/c", "echo", "Single" },
            run = "interval",
            timeout = 5,
            output = "text",
            classes = {},
            format = "{text}",
            icon = "",
            interval = 3600,
            tooltip = "Link the single monitor GlazeWM config and gather every workspace onto monitor 0",
            on_click = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command",
                         [[& "$HOME\dev\windows-dev\glazewm\switch-layout.ps1" -Layout Single]] },
        },
        layout_dual = {
            type = "custom",
            command = { "C:\\Windows\\System32\\cmd.exe", "/d", "/c", "echo", "Dual" },
            run = "interval",
            timeout = 5,
            output = "text",
            classes = {},
            format = "{text}",
            icon = "",
            interval = 3600,
            tooltip = "Link the dual monitor GlazeWM config and move each workspace to its bound monitor",
            on_click = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command",
                         [[& "$HOME\dev\windows-dev\glazewm\switch-layout.ps1" -Layout Dual]] },
        },
        -- A window module shows the focused window's title. Add "title" to a list to show it.
        -- title = {
        --     type = "window",
        --     max_length = 80, -- longer titles are cut with an ellipsis
        --     tooltip = "{title}", -- the whole title
        -- },
        --
        -- A custom module runs its command and shows what it printed. The command follows the same rules as
        -- on_click and runs with no window. run = "interval" runs it every interval and kills it with everything it
        -- started after timeout seconds. run = "continuous" takes no timeout: the command keeps running, each line it
        -- prints replaces the shown value, and when it exits its exit code shows as an alert and it starts again
        -- interval seconds later. output = "text" shows the first line. output = "json" reads one object, { "text": "...", "tooltip": "...",
        -- "alert": true, "class": "..." }, where only text is required, tooltip may span lines, alert draws the text
        -- in the module's .alert color, and class draws it in the color style.css gives that class, as
        -- #weather.rain. A class must be one the module's classes list, and style.css may style only those.
        -- Control characters (other than line breaks in a tooltip) fail the run, as does a failed command or an
        -- unlisted class, and each shows its reason as an alert. Add "weather" to a list to show it.
        -- weather = {
        --     type = "custom",
        --     -- Absolute, so another curl.exe earlier on PATH (such as MSYS2's) is never picked instead.
        --     command = { "C:\\Windows\\System32\\curl.exe", "--silent", "--fail", "https://wttr.in/?format=%c%t" },
        --     run = "interval",
        --     timeout = 10,
        --     output = "text",
        --     classes = {}, -- the classes a JSON output may name
        --     format = "{text}", -- {text} is the output's text, as a string
        --     icon = "",
        --     interval = 900,
        -- },
        --
        -- A counter module samples a Windows performance counter every interval, by its English path (as typeperf
        -- -q lists them), on this machine only. A * instance matches every instance, following them as they come and
        -- go, and combine makes them one value: sum, max or average (0 while none exist). The format and tooltip can
        -- use {value} (a number, as {value:.0f}) and {rate} (the value read as bytes per second, as "3.4 MB/s"). A
        -- path this machine has no counter for stops the config from loading. Add "gpu" to a list to show it.
        -- gpu = {
        --     type = "counter",
        --     counter = "\\GPU Engine(*engtype_3D)\\Utilization Percentage",
        --     combine = "sum",
        --     format = "{value:.0f}%",
        --     icon = "",
        --     interval = 2,
        -- },
    },
}
