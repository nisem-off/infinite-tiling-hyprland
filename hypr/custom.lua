-- ============================================================
-- [OPTIONAL] HOME WORKSPACE / ДОМАШНИЙ ВОРКСПЕЙС
-- ------------------------------------------------------------
-- RU: Постоянный именованный воркспейс "home" для домашнего экрана.
--     Раскомментируйте оба правила ниже, если хотите отдельный
--     пустой воркспейс с виджетами (например, Workspace 1),
--     а окна начинать с Workspace 2.
-- EN: Persistent named "home" workspace for a dashboard screen.
--     Uncomment both rules below if you want a dedicated empty
--     workspace for widgets (e.g. Workspace 1), with windows
--     starting at Workspace 2.
-- ============================================================

-- RU: Создаем постоянный именованный воркспейс для домашнего экрана
-- EN: Create a persistent named workspace for the home screen
-- hl.workspace_rule({
--     workspace = "name:home",
--     persistent = true,
-- })

-- RU: Правило: любое окно, которое пытается открыться на 'home', перемещается на воркспейс 2
-- EN: Rule: any window trying to open on 'home' is moved to workspace 2
-- hl.window_rule({
--     name = "no-windows-on-home",
--     match = { workspace = "name:home" },
--     workspace = "2"
-- })

-- ============================================================
-- [OPTIONAL] END HOME WORKSPACE / КОНЕЦ ДОМАШНЕГО ВОРКСПЕЙСА
-- ============================================================


-- ============================================================
-- 1. DIALOGS / ДИАЛОГИ
-- ------------------------------------------------------------
-- RU: Правило для диалогов: оставляем их на текущем воркспейсе
-- EN: Rule for dialogs: keep them on the current workspace
-- ============================================================
hl.window_rule({
    name = "keep-dialogs-here",
    match = { 
        class = "^(xdg-desktop-portal-gtk|pavucontrol|nm-connection-editor)$",
        float = true 
    },
    workspace = "current"
})

-- ============================================================
-- 2. COMPACTION / УПЛОТНЕНИЕ ВОРКСПЕЙСОВ
-- ------------------------------------------------------------
-- RU: Функция уплотнения (принимает ID воркспейса для возврата фокуса)
-- EN: Compaction function (takes workspace ID to restore focus to)
-- ============================================================
local function compact_workspaces(focus_ws_id)
    local windows = hl.get_windows()

    local groups = {}
    for _, w in ipairs(windows) do
        local ws_id = w.workspace and w.workspace.id or 0
        local c = w.class and string.lower(w.class) or ""
        
        -- RU: Игнорируем всплывающие окна Steam при проверке занятости стола
        -- EN: Ignore Steam popup windows when checking workspace occupancy
        local is_steam_popup = (c == "steam" and w.floating)
        
        if ws_id > 0 and not is_steam_popup then
            groups[ws_id] = groups[ws_id] or {}
            table.insert(groups[ws_id], w)
        end
    end

    local ids = {}
    for id in pairs(groups) do table.insert(ids, id) end
    table.sort(ids)

    local has_gap = false
    for i, id in ipairs(ids) do
        if i ~= id then 
            has_gap = true
            break 
        end
    end

    if not has_gap then 
        -- RU: Даже если дыр нет, фокус мог уйти. Возвращаем его, если нужно.
        -- EN: Even with no gaps, focus may have drifted. Restore it if needed.
        if focus_ws_id then
            hl.dispatch(hl.dsp.focus({ workspace = focus_ws_id }))
        end
        return 
    end

    -- RU: Уплотняем воркспейсы
    -- EN: Compact workspaces
    for i, old_id in ipairs(ids) do
        if i ~= old_id then
            for _, w in ipairs(groups[old_id]) do
                -- RU: ВСЕГДА перемещаем без следования фокуса
                -- EN: ALWAYS move without following focus
                local action = hl.dsp.window.move({
                    workspace = i,
                    window = w,
                    follow = false 
                })
                hl.dispatch(action)
            end
        end
    end

    -- RU: После уплотнения возвращаем фокус на исходный воркспейс (если он был)
    -- EN: After compaction, restore focus to the original workspace (if any)
    if focus_ws_id then
        hl.dispatch(hl.dsp.focus({ workspace = focus_ws_id }))
    end
end

-- ============================================================
-- 3. ON WINDOW CLOSE / ПРИ ЗАКРЫТИИ ОКНА
-- ------------------------------------------------------------
-- RU: Слушаем закрытие окон и запускаем уплотнение с задержкой
-- EN: Listen for window close and run compaction after a delay
-- ============================================================
hl.on("window.close", function(win)
    -- RU: Запоминаем, на каком воркспейсе мы находились В МОМЕНТ закрытия
    -- EN: Remember which workspace was active AT THE MOMENT of closing
    local active_ws = hl.get_active_workspace()
    local focus_ws_id = active_ws and active_ws.id or nil

    hl.timer(function()
        compact_workspaces(focus_ws_id)
    end, { timeout = 250, type = "oneshot" })
end)

-- ============================================================
-- 4. ON WINDOW OPEN / ПРИ ОТКРЫТИИ ОКНА
-- ------------------------------------------------------------
-- RU: Открытие новых окон: отправляем на максимальный воркспейс + 1
-- EN: New windows: send to the highest workspace + 1
-- ============================================================
hl.on("window.open", function(win)
    local c = win.class and string.lower(win.class) or ""
    
    -- RU: Пропускаем окна без класса
    -- EN: Skip windows without a class
    if c == "" then return end
    
    -- RU: Проверяем, является ли окно веб-приложением Chromium (PWA)
    -- EN: Check if the window is a Chromium web app (PWA)
    local is_pwa = c:match("^chrome%-") or c:match("^chromium")
    
    -- RU: Пропускаем плавающие окна, НО пропускаем веб-приложения Chromium дальше
    -- EN: Skip floating windows, BUT let Chromium web apps through
    if win.floating and not is_pwa then return end
    
    -- RU: Пропускаем известные системные диалоги
    -- EN: Skip known system dialogs
    if c:match("xdg%-desktop%-portal")
        or c:match("pavucontrol")
        or c:match("nm%-connection%-editor")
        or c:match("blueman") then
        return
    end

    -- RU: Ищем максимальный номер существующего воркспейса
    -- EN: Find the highest existing workspace ID
    local max_id = 0
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > max_id then max_id = ws.id end
    end
    
    -- RU: Отправляем новое окно на максимальный + 1
    -- EN: Send the new window to max + 1
    local action = hl.dsp.window.move({ 
        workspace = max_id + 1,
        window = win
    })
    hl.dispatch(action)
end)