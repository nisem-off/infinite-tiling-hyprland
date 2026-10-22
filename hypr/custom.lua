-- ============================================================
--  Infinite Tiling Hyprland — custom.lua
--  Бесконечный тайлинг для Hyprland / Infinite tiling for Hyprland
--
--  Автор / Author: nisem-off
--  Лицензия / License: см. LICENSE / see LICENSE
-- ============================================================


-- ============================================================
-- 1. HOME WORKSPACE / ИМЕНОВАННЫЙ ВОРКСПЕЙС "HOME"   [OPTIONAL]
-- ============================================================
-- RU: Опциональный постоянный именованный воркспейс "home".
--     Раскомментируйте блок ниже, если хотите отдельный "домашний"
--     экран, который всегда существует и отображается первым.
--     Также раскомментируйте блок 6 (автофокус на home) — иначе
--     при старте фокус останется на обычном воркспейсе 1.
--
-- EN: Optional persistent named workspace "home".
--     Uncomment the block below if you want a dedicated "home"
--     screen that always exists and is displayed first.
--     Also uncomment block 6 (home autofocus) — otherwise startup
--     focus stays on the regular workspace 1.
--
-- hl.workspace_rule({
--     workspace = "name:home",
--     persistent = true,
-- })


-- ============================================================
-- 2. DIALOG WINDOWS / ДИАЛОГОВЫЕ ОКНА
-- ============================================================
-- RU: Диалоги (громкость, сеть и т.д.) оставляем на текущем воркспейсе.
-- EN: Keep dialogs (volume, network, etc.) on the current workspace.
hl.window_rule({
    name = "keep-dialogs-here",
    match = {
        class = "^(xdg-desktop-portal-gtk|pavucontrol|nm-connection-editor)$",
        float = true
    },
    workspace = "current"
})


-- ============================================================
-- 3. COMPACTION / УПЛОТНЕНИЕ ВОРКСПЕЙСОВ
-- ============================================================
-- RU: Удаляет "дырки" в нумерации воркспейсов после закрытия окон.
--     Например, если остались 1, 2, 4 — окна с 4-го переедут на 3-й.
-- EN: Removes "holes" in workspace numbering after windows are closed.
--     E.g. if 1, 2, 4 remain — windows from 4 move to 3.
local function compact_workspaces(focus_ws_id)
    local windows = hl.get_windows()

    -- RU: Собираем окна по воркспейсам.
    -- EN: Group windows by workspace.
    local groups = {}
    for _, w in ipairs(windows) do
        local ws_id = w.workspace and w.workspace.id or 0
        local c = w.class and string.lower(w.class) or ""

        -- RU: Игнорируем всплывающие окна Steam (не считаем их занятостью).
        -- EN: Ignore Steam popups (they don't count as occupancy).
        local is_steam_popup = (c == "steam" and w.floating)

        -- RU: Только положительные воркспейсы (1, 2, 3...).
        -- EN: Only positive workspaces (1, 2, 3...).
        if ws_id > 0 and not is_steam_popup then
            groups[ws_id] = groups[ws_id] or {}
            table.insert(groups[ws_id], w)
        end
    end

    local ids = {}
    for id in pairs(groups) do table.insert(ids, id) end
    table.sort(ids)

    -- RU: Проверяем, есть ли "дырки" (1, 2, 4 → дырка на 3).
    -- EN: Check if there are gaps (1, 2, 4 → gap at 3).
    local has_gap = false
    for i, id in ipairs(ids) do
        if i ~= id then
            has_gap = true
            break
        end
    end

    if not has_gap then
        -- RU: Дырок нет — просто возвращаем фокус на исходный воркспейс.
        -- EN: No gaps — just restore focus to the original workspace.
        if focus_ws_id then
            hl.dispatch(hl.dsp.focus({ workspace = focus_ws_id }))
        end
        return
    end

    -- RU: Сдвигаем окна влево, заполняя дырки.
    -- EN: Shift windows left to fill the gaps.
    for i, old_id in ipairs(ids) do
        if i ~= old_id then
            for _, w in ipairs(groups[old_id]) do
                local action = hl.dsp.window.move({
                    workspace = i,
                    window = w,
                    follow = false
                })
                hl.dispatch(action)
            end
        end
    end

    -- RU: Возвращаем фокус на исходный воркспейс (если был).
    -- EN: Restore focus to the original workspace (if any).
    if focus_ws_id then
        hl.dispatch(hl.dsp.focus({ workspace = focus_ws_id }))
    end
end


-- ============================================================
-- 4. WINDOW CLOSE / ЗАКРЫТИЕ ОКОН
-- ============================================================
-- RU: Слушаем закрытие окон и запускаем уплотнение с задержкой 250 мс.
--     Задержка нужна, чтобы Hyprland успел обновить состояние.
-- EN: Listen for window close and run compaction after 250 ms.
--     The delay lets Hyprland update its state first.
hl.on("window.close", function(win)
    local active_ws = hl.get_active_workspace()
    local focus_ws_id = active_ws and active_ws.id or nil

    hl.timer(function()
        compact_workspaces(focus_ws_id)
    end, { timeout = 250, type = "oneshot" })
end)


-- ============================================================
-- 5. WINDOW OPEN / ОТКРЫТИЕ НОВЫХ ОКОН
-- ============================================================
-- RU: Новые окна отправляем на первый СВОБОДНЫЙ воркспейс.
--     Это и есть "бесконечный тайлинг": 1 окно = 1 воркспейс.
--     Исключения: диалоги, floating-окна (кроме PWA), утилиты.
-- EN: Send new windows to the first FREE workspace.
--     This is the "infinite tiling": 1 window = 1 workspace.
--     Exceptions: dialogs, floating windows (except PWA), utilities.
hl.on("window.open", function(win)
    local c = win.class and string.lower(win.class) or ""
    if c == "" then return end

    -- RU: PWA-окна (Chrome/Chromium) считаем "нормальными", не floating.
    -- EN: Treat PWA windows (Chrome/Chromium) as regular, not floating.
    local is_pwa = c:match("^chrome%-") or c:match("^chromium")
    if win.floating and not is_pwa then return end

    -- RU: Диалоги и утилиты не трогаем — остаются на текущем воркспейсе.
    -- EN: Skip dialogs and utilities — they stay on the current workspace.
    if c:match("xdg%-desktop%-portal")
        or c:match("pavucontrol")
        or c:match("nm%-connection%-editor")
        or c:match("blueman") then
        return
    end

    -- RU: Собираем занятые воркспейсы (кроме самого нового окна).
    -- EN: Collect occupied workspaces (excluding the new window itself).
    local occupied = {}
    for _, w in ipairs(hl.get_windows()) do
        if w.address ~= win.address and w.workspace and w.workspace.id > 0 then
            occupied[w.workspace.id] = true
        end
    end

    -- RU: Ищем первый свободный воркспейс начиная с 1.
    -- EN: Find the first free workspace starting from 1.
    local target_ws = 1
    while occupied[target_ws] do
        target_ws = target_ws + 1
    end

    -- RU: Перемещаем окно и фокусируемся на нём.
    -- EN: Move the window and focus it.
    local action = hl.dsp.window.move({
        workspace = target_ws,
        window = win,
        follow = true
    })
    hl.dispatch(action)
end)


-- ============================================================
-- 6. HOME AUTOFOCUS / АВТОФОКУС НА "HOME"   [OPTIONAL]
-- ============================================================
-- RU: Опциональный автофокус на "home" при старте системы.
--     Раскомментируйте ВМЕСТЕ с блоком 1 (workspace_rule для home).
--     Если блок 1 закомментирован — этот блок безопасно упадёт
--     обратно на обычный воркспейс 1 (см. fallback ниже).
--     Если вы НЕ хотите использовать home — оставьте блок
--     закомментированным, и система будет работать с обычными
--     нумерованными воркспейсами.
--
-- EN: Optional autofocus on "home" at startup.
--     Uncomment TOGETHER with block 1 (workspace_rule for home).
--     If block 1 is commented out — this block safely falls back
--     to the regular workspace 1 (see fallback below).
--     If you DON'T want home — leave this block commented out,
--     and the system will work with regular numbered workspaces.
--
-- hl.on("hyprland.start", function()
--     -- RU: Небольшая задержка, чтобы Hyprland успел применить workspace_rule.
--     -- EN: Small delay so Hyprland can apply workspace_rule first.
--     hl.timer(function()
--         local target = 1
--
--         -- RU: Проверяем, существует ли воркспейс "home".
--         --     pcall защищает от отсутствия hl.get_workspaces() в старых API.
--         -- EN: Check if the "home" workspace exists.
--         --     pcall guards against missing hl.get_workspaces() in old APIs.
--         local ok, workspaces = pcall(hl.get_workspaces)
--         if ok and workspaces then
--             for _, ws in ipairs(workspaces) do
--                 if ws.name == "home" then
--                     target = "name:home"
--                     break
--                 end
--             end
--         end
--
--         -- RU: Fallback на воркспейс 1, если home не найден.
--         -- EN: Fall back to workspace 1 if home isn't found.
--         hl.dispatch(hl.dsp.focus({ workspace = target }))
--     end, { timeout = 500, type = "oneshot" })
-- end)
