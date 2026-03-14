return {
    run = function(args)
        local hyprland = require("lib.hyprland")
        local utils = require("lib.utils")

        utils.check_args(#args ~= 4, "Usage: hyprfloat snap <x0_frac> <x1_frac> <y0_frac> <y1_frac>")

        local x0_frac = tonumber(args[1])
        local x1_frac = tonumber(args[2])
        local y0_frac = tonumber(args[3])
        local y1_frac = tonumber(args[4])

        utils.check_args(not (x0_frac and x1_frac and y0_frac and y1_frac), "All arguments must be numbers")

        local ctx = hyprland.get_active_context()
        utils.check_args(not ctx, "No active window/monitor context")

        if not ctx.window.floating then
            utils.debug("Ignoring snap for tiling window")
            return
        end

        local function get_snap_area(monitor)
            local scale = monitor.scale or 1
            local pw, ph = monitor.width, monitor.height
            if monitor.transform == 1 or monitor.transform == 3 then
                pw, ph = ph, pw
            end
            local lw = math.floor(pw / scale)
            local lh = math.floor(ph / scale)
            local res_bottom = monitor.reserved[4]
            local gap = ctx.border_gap.gaps_out.left - ctx.border_gap.border_size
            if gap < 0 then gap = 0 end
            local bar_data = hyprland.hyprctl_json("getoption plugin:hyprbars:bar_height")
            local bar_height = (bar_data and bar_data.int) or 0
            return {
                x = monitor.x + gap,
                y = monitor.y + bar_height + gap,
                w = lw - gap * 2,
                h = lh - res_bottom - bar_height - gap * 2,
            }
        end

        local function do_snap(area, x0, x1, y0, y1)
            local new_x = area.x + math.floor(area.w * x0)
            local new_y = area.y + math.floor(area.h * y0)
            local new_w = math.floor(area.w * (x1 - x0))
            local new_h = math.floor(area.h * (y1 - y0))
            hyprland.hyprctl_batch(
                "dispatch fullscreenstate 0",
                string.format("dispatch resizeactive exact %d %d", new_w, new_h),
                string.format("dispatch moveactive exact %d %d", new_x, new_y),
                "dispatch alterzorder top"
            )
        end

        local monitors = hyprland.get_monitors()
        local cur_monitor = nil
        for _, m in ipairs(monitors) do
            if m.id == ctx.window.monitor then cur_monitor = m; break end
        end
        if not cur_monitor then return end

        local area = get_snap_area(cur_monitor)
        local tolerance = 15

        -- Check if already snapped to left or right
        local wx = ctx.window.at[1]
        local ww = ctx.window.size[1]
        local half_w = math.floor(area.w * 0.5)
        local at_left = math.abs(wx - area.x) < tolerance and math.abs(ww - half_w) < tolerance
        local at_right = math.abs(wx - (area.x + half_w)) < tolerance and math.abs(ww - half_w) < tolerance

        -- Sort monitors by x position to find neighbors
        table.sort(monitors, function(a, b) return a.x < b.x end)
        local cur_idx = nil
        for i, m in ipairs(monitors) do
            if m.id == cur_monitor.id then cur_idx = i; break end
        end

        local snapping_left = (x0_frac == 0 and x1_frac == 0.5)
        local snapping_right = (x0_frac == 0.5 and x1_frac == 1)

        if snapping_left and at_left and cur_idx and cur_idx > 1 then
            -- Move to left monitor, snap right
            local target = monitors[cur_idx - 1]
            hyprland.hyprctl("dispatch movewindow mon:" .. target.name)
            -- Re-fetch context after move
            local new_area = get_snap_area(target)
            do_snap(new_area, 0.5, 1, 0, 1)
            return
        elseif snapping_right and at_right and cur_idx and cur_idx < #monitors then
            -- Move to right monitor, snap left
            local target = monitors[cur_idx + 1]
            hyprland.hyprctl("dispatch movewindow mon:" .. target.name)
            local new_area = get_snap_area(target)
            do_snap(new_area, 0, 0.5, 0, 1)
            return
        end

        do_snap(area, x0_frac, x1_frac, y0_frac, y1_frac)
    end,
    help = {
        short = "Snaps the active window to a fraction of the screen.",
        usage = "snap <x0> <x1> <y0> <y1>",
        long = [[
Snaps the active window to a fractional portion of the screen.
If already snapped to an edge, moves to the adjacent monitor and snaps to the opposite side.

**Arguments:**
- `<x0>` Required. Left position as a fraction of screen width (e.g., 0.0).
- `<x1>` Required. Right position as a fraction of screen width (e.g., 0.5 for half width).
- `<y0>` Required. Top position as a fraction of screen height (e.g., 0.0).
- `<y1>` Required. Bottom position as a fraction of screen height (e.g., 1.0 for full height).
]]
    }
}
