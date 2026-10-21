-- ============================================================
-- INPUT CONFIGURATION / НАСТРОЙКА ВВОДА
-- ============================================================
hl.config({
    input = {
        -- RU: Раскладки клавиатуры (переключение по Alt+Shift)
        -- EN: Keyboard layouts (switch with Alt+Shift)
        kb_layout = "us,ru",
        kb_variant = "",
        kb_model = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules = "",
        -- RU: Фокус следует за мышью (1 = включено)
        -- EN: Focus follows mouse (1 = enabled)
        follow_mouse = 1,
        -- RU: Чувствительность курсора: -1.0 - 1.0, 0 = без изменений
        -- EN: Cursor sensitivity: -1.0 to 1.0, 0 = no modification
        sensitivity = 0,
        touchpad = {
            -- RU: Естественная прокрутка тачпада
            -- EN: Natural touchpad scrolling
            natural_scroll = true,
        },
    },
    cursor = {
        -- RU: Отключает большинство перемещений курсора
        -- EN: Disables most cursor warps
        no_warps = true,
        -- RU: Отключает перемещение курсора при смене рабочего стола
        -- EN: Disables cursor warp on workspace switch
        warp_on_change_workspace = 0,
        -- RU: Опционально: возвращает курсор в последнюю позицию
        -- EN: Optional: restores cursor to the last position
        -- persistent_warps = true,
    },
})