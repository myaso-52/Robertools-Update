script_name("Robertools") 
script_author("Sanek Prokuratura")   
script_version("3.1") 

local samplua = require 'lib.samp.events'
local ffi = require 'ffi'
local inicfg = require 'inicfg'
local http = require 'ssl.https' 

ffi.cdef[[
    bool MessageBeep(unsigned int uType);
]]

-- Ссылки строго на ваш репозиторий GitHub (myaso-52)
local github_user = "myaso-52"
local github_repo = "Robertools-Update"
local url_version = "https://githubusercontent.com" .. github_user .. "/" .. github_repo .. "/main/version.txt"
local url_script = "https://githubusercontent.com" .. github_user .. "/" .. github_repo .. "/main/Robertools.lua"
local url_staff = "https://githubusercontent.com" .. github_user .. "/" .. github_repo .. "/main/Robertools_Staff.uni.ini"

local config_dir = getWorkingDirectory() .. "/config"
if not doesDirectoryExist(config_dir) then createDirectory(config_dir) end
local ini_path = "Robertools_Staff.uni.ini"

function checkAutoUpdate()
    local response, code = http.request(url_version)
    if code == 200 and response then
        local server_version = response:match("^%s*(.-)%s*$")
        if server_version and server_version ~= thisScript().version then
            sampAddChatMessage("{00FFCC}[Robertools v3]{FFFFFF} Найдено обновление! Скачиваю версию " .. server_version, -1)
            local new_code, script_code = http.request(url_script)
            if script_code == 200 and new_code then
                local file = io.open(thisScript().path, "wb")
                if file then file:write(new_code) file:close() end
                sampAddChatMessage("{00FF00}[Robertools v3]{FFFFFF} Успешно обновлено! Нажмите Ctrl + R.", -1)
            end
        end
    end
end

function downloadStaffList()
    local response, code = http.request(url_staff)
    if code == 200 and response then
        local file = io.open(config_dir .. "/" .. ini_path, "wb")
        if file then file:write(response) file:close() end
    end
end

pcall(downloadStaffList)
local default_ini = { Staff = { ["Sanek_Prokuratura"] = "3", ["Robert_Robinson"] = "3" }, Blacklist = {} }
local main_ini = inicfg.load(default_ini, ini_path) or default_ini
local config_path = "Robertools_config.ini"
local default_config = {
    Answers = {
        ans1 = "Здравствуйте, спешу на помощь! Приятной игры.",
        ans2 = "Здравствуйте, не засоряйте репорт. Приятной игры!",
        ans3 = "Здравствуйте, начинаю слежку. Приятной игры.",
        ans4 = "Здравствуйте, Оставьте жалобу в свободной группе ВК - @inferno_Sv",
        ans5 = "Здравствуйте, пожалуйста, ожидайте. Приятной игры!",
        ans6 = "Здравствуйте, приятной игры от Roberta )"
    }
}
local answer_cfg = inicfg.load(default_config, config_path) or default_config
local ans1, ans2, ans3 = answer_cfg.Answers.ans1, answer_cfg.Answers.ans2, answer_cfg.Answers.ans3
local ans4, ans5, ans6 = answer_cfg.Answers.ans4, answer_cfg.Answers.ans5, answer_cfg.Answers.ans6

local last_report_id, invis_active, is_panel_banned = "", false, false
local panel_ban_reason, razdash_active, razdash_word = "Не указана", false, ""
local razdash_item_id, razdash_value, razdash_mode = "", "", 1
local tp_stage, mute_stage, target_mute_id = 0, 0, nil
local items_database = {
    ["1"] = "игрового уровня", ["2"] = "законопослушности", ["3"] = "материалов",
    ["4"] = "убийств", ["5"] = "номера телефона", ["6"] = "EXP (опыта)",
    ["7"] = "денег в банке", ["8"] = "денег на мобиле", ["9"] = "наличных денег",
    ["10"] = "аптечек", ["15"] = "наркозависимости", ["16"] = "наркотиков"
}
local objects_database = {
    ["1"] = "шляпу курицы", ["2"] = "огонек на голову", ["3"] = "мигалку на голову",
    ["4"] = "черную маску", ["10"] = "маску дракона", ["11"] = "лазер на голову",
    ["12"] = "комплект всемогущий", ["13"] = "попугая на плечо", ["14"] = "яркий свет",
    ["15"] = "большой М4", ["16"] = "объект-пустышка", ["17"] = "костюм попугая"
}
local insult_words = { "чмо", "пидор", "еблан", "даун", "аутист", "тупорылый", "идиот", "придурок", "хуйло", "гандон", "mразь", "шлюха", "долбоеб", "пидорас", "уебок", "уебан", "уебанище" }
local rodnya_words = { "мать", "маме", "маму", "мама", "папа", "папу", "паме", "отчим", "отец", "отца", "отцу", "батя", "бате", "мачех", "родител", "выбляд", "mq", "mku", "сш", "безмамн", "без мамн" }

function getItemNameById(id, mode)
    return mode == 2 and (objects_database[tostring(id)] or "объект #" .. tostring(id)) or (items_database[tostring(id)] or "предмет #" .. tostring(id))
end
function string.cp1251lower(str)
    local upper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local lower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюяabcdefghijklmnopqrstuvwxyz"
    local res = ""
    for i = 1, #str do
        local c = str:sub(i, i)
        local pos = upper:find(c, 1, true)
        res = res .. (pos and lower:sub(pos, pos) or c)
    end
    return res
end

local function formatNickname(nick)
    local formatted = nick:lower():gsub("^%l", string.upper)
    return formatted:gsub("_(%l)", function(l) return "_" .. l:upper() end)
end

function logMuteAction(player_id, reason_word, type_id)
    local log_path = config_dir .. "/Robertools_Mutes.txt"
    local file = io.open(log_path, "a")
    if file then
        local time_str = os.date("%Y-%m-%d [%H:%M:%S]")
        local type_str = (type_id == 2) and "Оск. Родных" or "Мат/Оск"
        local p_name = sampIsPlayerConnected(tonumber(player_id)) and sampGetPlayerNickname(tonumber(player_id)) or "Unknown"
        file:write(string.format("%s Нарушитель: %s[%s] | Тип: %s | Триггер: %s\n", time_str, p_name, player_id, type_str, reason_word))
        file:close()
    end
end
function checkAndMuteAnyChat(full_line_text)
    if is_panel_banned or mute_stage > 0 then return false end 
    local lower_text = string.cp1251lower(full_line_text)
    
    for _, word in ipairs(rodnya_words) do
        if string.find(lower_text, word, 1, true) then
            local player_id = full_line_text:match("%[%s*(%d+)%s*%]")
            if player_id then
                target_mute_id = tonumber(player_id)
                mute_stage = 2 
                pcall(ffi.C.MessageBeep, 0)
                sampAddChatMessage(string.format("{FF3333}[Warning]{FFFFFF} Запрещенное слово \"%s\", мут через 2с", word), -1)
                logMuteAction(player_id, word, 2)
                lua_thread.create(function() wait(2000) sampSendChat(string.format("/mute %s", player_id)) end)
                return true
            end
        end
    end
    for _, word in ipairs(insult_words) do
        if string.find(lower_text, word, 1, true) then
            local player_id = full_line_text:match("%[%s*(%d+)%s*%]")
            if player_id then
                target_mute_id = tonumber(player_id)
                mute_stage = 1 
                pcall(ffi.C.MessageBeep, 0)
                sampAddChatMessage(string.format("{FF3333}[Warning]{FFFFFF} Запрещенное слово \"%s\", мут через 2с", word), -1)
                logMuteAction(player_id, word, 1)
                lua_thread.create(function() wait(2000) sampSendChat(string.format("/mute %s", player_id)) end)
                return true
            end
        end
    end
    return false
end

function getPlayerStaffLevel()
    local result, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if not result or not my_id then return 1, "{22FF22}Юзер" end
    local my_nickname = sampGetPlayerNickname(my_id)
    local low_nick = my_nickname:lower()
    
    -- НОВОЕ: Обозначения цветов для вывода статуса в чат
    if low_nick == "robert_robinson" then return 3, "{FF3333}Разработчик {FFFFFF}| ВК: {00FFCC}@dimo4kaenergy" end
    if low_nick == "sanek_prokuratura" then return 3, "{FF3333}Разработчик" end
    
    if main_ini and main_ini.Staff then
        for nick, raw_val in pairs(main_ini.Staff) do
            if nick:lower() == low_nick then
                local lvl_str = tostring(raw_val):match("^([^:]+)") or "1"
                local r_level = tonumber(lvl_str) or 1
                if r_level == 3 then return 3, "{FF3333}Разработчик"
                elseif r_level == 2 then return 2, "{FF9900}Администратор"
                else return 1, "{22FF22}Юзер" end
            end
        end
    end
    return 1, "{22FF22}Юзер" 
end

function checkPanelBanStatus()
    local result, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if not result or not my_id then return false end
    local my_nickname = sampGetPlayerNickname(my_id)
    local low_nick = my_nickname:lower()
    if low_nick == "robert_robinson" or low_nick == "sanek_prokuratura" then return false end
    if main_ini and main_ini.Blacklist then
        for nick, reason in pairs(main_ini.Blacklist) do
            if nick:lower() == low_nick then
                panel_ban_reason = (tostring(reason) == "true" or reason == "") and "Не указана" or tostring(reason)
                return true
            end
        end
    end
    return false
end

function hasAccess(required_level, show_error)
    if is_panel_banned then return false end 
    local current_level, _ = getPlayerStaffLevel()
    if current_level >= required_level then return true end
    if show_error then sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Недостаточно прав.", -1) end
    return false
end
function registerAdminCommands()
    sampRegisterChatCommand("panelban", function(param)
        if not hasAccess(2, true) then return end
        param = param:match("^%s*(.-)%s*$")
        local target_nick, reason = param:match("(%S+)%s+(.+)")
        if not target_nick or not reason then sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Формат: /panelban [Ник] [Причина]", -1) return end
        target_nick = formatNickname(target_nick)
        if target_nick:lower() == "robert_robinson" or target_nick:lower() == "sanek_prokuratura" then return end
        main_ini.Blacklist[target_nick] = reason
        inicfg.save(main_ini, ini_path)
        sampAddChatMessage(string.format("{33FF33}[Панель]{FFFFFF} %s забанен в панели. Причина: %s", target_nick, reason), -1)
    end)

    sampRegisterChatCommand("panelunban", function(param)
        if not hasAccess(2, true) then return end
        param = param:match("^%s*(.-)%s*$")
        if param == "" then sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Формат: /panelunban [Ник]", -1) return end
        local low_param = param:lower()
        local found = false
        if main_ini.Blacklist then
            for nick, _ in pairs(main_ini.Blacklist) do
                if nick:lower() == low_param then main_ini.Blacklist[nick] = nil found = true end
            end
        end
        if found then inicfg.save(main_ini, ini_path) sampAddChatMessage(string.format("{33FF33}[Панель]{FFFFFF} Игрок %s разбанен!", formatNickname(param)), -1) end
    end)

    sampRegisterChatCommand("rbanlist", function()
        if not hasAccess(2, true) then return end
        sampAddChatMessage("{33FFF3}============== [ ЧЕРНЫЙ СПИСОК ПАНЕЛИ ] ==============", -1)
        local count = 0
        if main_ini.Blacklist then
            for nick, reason in pairs(main_ini.Blacklist) do
                count = count + 1
                sampAddChatMessage(string.format("{FFFFFF}%d. {FFFF00}%s {FFFFFF}— {FF3333}%s", count, nick, tostring(reason)), -1)
            end
        end
        if count == 0 then sampAddChatMessage("{22FF22}Черный список пуст!", -1) end
    end)

    sampRegisterChatCommand("setrang", function(param)
        if not hasAccess(3, true) then return end 
        param = param:match("^%s*(.-)%s*$")
        local target_nick, target_level = param:match("(%S+)%s+(%d+)")
        
        -- ПОДСКАЗКА: Если ввели команду неверно, пишется подробная подсказка как надо
        if not target_nick or not target_level then 
            sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Формат: /setrang [Ник] [1/2/3]", -1) 
            sampAddChatMessage("{FFFF00}[Подсказка]{FFFFFF} 1 = Юзер (Зеленый), 2 = Администратор (Оранжевый), 3 = Разработчик (Красный)", -1)
            return 
        end
        
        local level_num = tonumber(target_level)
        if level_num < 1 or level_num > 3 then 
            sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Неверный ранг. Доступны только 1, 2 или 3.", -1) 
            return 
        end
        
        target_nick = formatNickname(target_nick)
        main_ini.Staff[target_nick] = tostring(level_num)
        inicfg.save(main_ini, ini_path)
        local r_names = {"{22FF22}Юзер", "{FF9900}Администратор", "{FF3333}Разработчик"}
        sampAddChatMessage(string.format("{33FF33}[Панель]{FFFFFF} Ранг %s изменен на: %s", target_nick, r_names[level_num]), -1)
    end)
end

function sendReportAnswer(player_id, answer_text)
    if is_panel_banned or player_id == "" or player_id == nil then return end
    sampSendChat(string.format("/pm %s %s", player_id, answer_text))
    sampAddChatMessage(string.format("{33FF33}[Robertools PM]{FFFFFF} Отвечено ID: {FFFF00}%s", player_id), -1)
end
function registerGameCommands()
    sampRegisterChatCommand("go", function(param)
        if not hasAccess(1, true) then return end
        local word, item_id, val = param:match("(%S+)%s+(%d+)%s+(%d+)")
        if not word or not item_id or not val then sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Формат: /go [Слово] [ID_Предмета] [Кол-во]", -1) return end
        razdash_word = string.cp1251lower(word)
        razdash_item_id = item_id
        razdash_value = val
        razdash_mode = 1
        razdash_active = true
        local prize_name = getItemNameById(item_id, 1)
        sampSendChat(string.format("/aad [РАЗДАЧА] Кто первый напишет слово '%s' - получит %s %s!", word, val, prize_name))
    end)

    sampRegisterChatCommand("goobj", function(param)
        if not hasAccess(1, true) then return end
        local word, obj_id = param:match("(%S+)%s+(%d+)")
        if not word or not obj_id then sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Формат: /goobj [Слово] [ID_Объекта]", -1) return end
        razdash_word = string.cp1251lower(word)
        razdash_item_id = obj_id
        razdash_value = "1"
        razdash_mode = 2
        razdash_active = true
        local obj_name = getItemNameById(obj_id, 2)
        sampSendChat(string.format("/aad [РАЗДАЧА] Кто первый напишет слово '%s' - получит %s!", word, obj_name))
    end)

    sampRegisterChatCommand("rw", function(param)
        if not hasAccess(1, true) then return end
        local target_id = tonumber(param:match("%d+"))
        if not target_id then sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Формат: /rw [ID Игрока]", -1) return end
        if not razdash_active then sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Нет активных раздач.", -1) return end
        if sampIsPlayerConnected(target_id) then
            local p_name = sampGetPlayerNickname(target_id)
            local prize_name = getItemNameById(razdash_item_id, razdash_mode)
            if razdash_mode == 2 then
                sampSendChat(string.format("/aad [РАЗДАЧА] Победитель — %s[%s]! Приз: %s", p_name, target_id, prize_name))
                lua_thread.create(function() wait(1000) sampSendChat(string.format("/object %s", target_id)) end)
            else
                sampSendChat(string.format("/aad [РАЗДАЧА] Победитель — %s[%s]! Приз: %s %s", p_name, target_id, razdash_value, prize_name))
                lua_thread.create(function() wait(1000) sampSendChat(string.format("/setstat %s %s %s", target_id, razdash_item_id, razdash_value)) end)
            end
            razdash_active = false
        else
            sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Игрок не в сети.", -1)
        end
    end)
    sampRegisterChatCommand("stafflist", function()
        if not hasAccess(1, true) then return end
        sampAddChatMessage("{33FFF3}============== [ СОСТАВ АДМИНИСТРАЦИИ ROBERTOOLS ] ==============", -1)
        if main_ini.Staff then
            for nick, raw_val in pairs(main_ini.Staff) do
                local lvl_str = tostring(raw_val):match("^([^:]+)") or "1"
                local level_num = tonumber(lvl_str) or 1
                
                -- ИСПРАВЛЕНО: Теперь Юзер подсвечен зеленым, Админ оранжевым, а Разработчик красным цветом
                local text_lvl = "{22FF22}Юзер"
                if level_num == 3 then text_lvl = "{FF3333}Разработчик"
                elseif level_num == 2 then text_lvl = "{FF9900}Администратор" end
                
                if nick:lower() == "robert_robinson" then
                    sampAddChatMessage(string.format("{FFFFFF}- %s — %s {FFFFFF}| ВК: {00FFCC}@dimo4kaenergy", nick, text_lvl), -1)
                else
                    sampAddChatMessage(string.format("{FFFFFF}- %s — %s", nick, text_lvl), -1)
                end
            end
        end
    end)

    sampRegisterChatCommand("dg", function(param)
        if not hasAccess(1, true) then return end
        local target_id = param:match("%d+") or ""
        if target_id == "" then sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Формат: /dg [ID Игрока]", -1) return end
        sampSendChat(string.format("/givegun %s 24 9999", target_id))
    end)

    sampRegisterChatCommand("nb", function()
        if not hasAccess(1, true) then return end
        if tp_stage > 0 then return end
        tp_stage = 1 sampSendChat("/tp")
    end)

    sampRegisterChatCommand("rthelp", function()
        -- АНИМАЦИЯ СОХРАНЕНА: Пошаговый вывод текста с микрозадержками wait(50)
        lua_thread.create(function()
            local _, current_txt = getPlayerStaffLevel()
            sampAddChatMessage("{33FFF3}=============== [ СПРАВКА ПО КОМАНДАМ " .. "ROBERTOOLS ] ===============", -1)
            wait(50)
            sampAddChatMessage(string.format("{FFFFFF}Ваш текущий статус: %s", current_txt), -1)
            wait(50)
            sampAddChatMessage("{FFFFFF}— {22FF22}[Доступно с ранга: Юзер]{FFFFFF} —", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/go [Слово] [ID_Пред] [Кол] " .. "{FFFFFF}— Начать авто-раздачу предметов сервера (/setstat)", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/goobj [Слово] [ID_Об]    " .. "{FFFFFF}— Начать авто-раздачу объектов из списка (/object)", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/rw [ID победителя]        " .. "{FFFFFF}— Вручную выбрать и наградить победителя раздачи", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/stafflist                " .. "{FFFFFF}— Посмотреть весь список администрации штата", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/dg [ID] {FFFFFF}— Дигл (9999 патрон) " .. "| {33FF33}/nb {FFFFFF}— Телепорт на Небоскрёб", -1)
            wait(50)
            sampAddChatMessage("{FFFFFF}— {FF9900}[Доступно с ранга: " .. "Администратор]{FFFFFF} —", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/panelban [Ник] [Прич] {FFFFFF}— Бан " .. "| {33FF33}/panelunban [Ник] {FFFFFF}— Разбан в панели", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/rbanlist {FFFFFF}— ЧС панели " .. "| {FFFFFF}— {FF3333}[Ранг: Разработчик]{FFFFFF} —", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/setrang [Ник] [1/2/3]     " .. "{FFFFFF}— Изменить ранг (1-Юзер / 2-Админ / 3-Разраб)", -1)
            wait(50)
            sampAddChatMessage("{33FFF3}===================================================================", -1)
        end)
    end)
end
function main()
    while not isSampAvailable() do wait(100) end
    pcall(checkAutoUpdate)
    registerAdminCommands()
    registerGameCommands()
    
    if checkPanelBanStatus() then
        is_panel_banned = true
        sampAddChatMessage("[Robertools] ОШИБКА! ВЫ ЗАБАНЕНЫ В ПАНЕЛИ!", -1)
        wait(500) thisScript():unload() return
    end
    
    local _, txt_status = getPlayerStaffLevel()
    sampAddChatMessage("{00FFCC}_________________________________________________", -1)
    sampAddChatMessage("{00FFCC}| {33FF33}RoberTools v3 успешно запущен! [ОБЩИЙ ГИТХАБ-НЕТВОРК]", -1)
    sampAddChatMessage(string.format("{00FFCC}| {FFFFFF}Должность: %s", txt_status), -1)
    sampAddChatMessage("{00FFCC}| {FFFF00}ONLINE | Автор: {FF9933}Санек Прокуратура", -1)
    sampAddChatMessage("{00FFCC}_________________________________________________", -1)

    while true do
        wait(0)
        if not sampIsChatInputActive() and not sampIsDialogActive() and not is_panel_banned then
            if isKeyJustPressed(0x58) then sampSendChat("/re off") end
            if last_report_id ~= "" and isKeyDown(0x12) then 
                if isKeyJustPressed(0x31) then sendReportAnswer(last_report_id, ans1)
                elseif isKeyJustPressed(0x32) then sendReportAnswer(last_report_id, ans2)
                elseif isKeyJustPressed(0x33) then sendReportAnswer(last_report_id, ans3)
                elseif isKeyJustPressed(0x34) then sendReportAnswer(last_report_id, ans4)
                elseif isKeyJustPressed(0x35) then sendReportAnswer(last_report_id, ans5)
                elseif isKeyJustPressed(0x36) then sendReportAnswer(last_report_id, ans6)
                end
            end
        end
    end
end
function samplua.onServerMessage(color, text)
    if is_panel_banned then return end
    local lower_text = string.cp1251lower(text)
    
    if lower_text:find("жалоба от") or lower_text:find("репорт от") then
        local r_id = text:match("%[%s*(%d+)%s*%]")
        if r_id then last_report_id = tostring(r_id) ffi.C.MessageBeep(0) end
        return
    end

    if razdash_active and string.find(lower_text, razdash_word, 1, true) then
        local winner_id = text:match("%[%s*(%d+)%s*%]")
        if winner_id then
            local res_my_id, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            local winner_name = sampGetPlayerNickname(tonumber(winner_id)) or ""
            
            if tonumber(winner_id) ~= tonumber(my_id) and not lower_text:find("администратор") and not lower_text:find("админ") and not lower_text:find("a:%s") then
                local prize_name = getItemNameById(razdash_item_id, razdash_mode)
                if razdash_mode == 2 then
                    sampSendChat(string.format("/aad [РАЗДАЧА] Победитель — %s[%s]! Приз: %s", winner_name, winner_id, prize_name))
                    lua_thread.create(function() wait(1000) sampSendChat(string.format("/object %s", winner_id)) end)
                else
                    sampSendChat(string.format("/aad [РАЗДАЧА] Победитель — %s[%s]! Приз: %s %s", winner_name, winner_id, razdash_value, prize_name))
                    lua_thread.create(function() wait(1000) sampSendChat(string.format("/setstat %s %s %s", winner_id, razdash_item_id, razdash_value)) end)
                end
                razdash_active = false
            end
        end
    end
    checkAndMuteAnyChat(text)
    
    -- НОВОЕ ФУНКЦИОНАЛ: Обозначение пользователей в чате!
    -- Скрипт сканирует входящий чат, находит никнеймы ваших админов и автоматически 
    -- красит их прямо в сообщениях сервера в зависимости от их рангов.
    if main_ini and main_ini.Staff then
        for staff_nick, raw_val in pairs(main_ini.Staff) do
            if text:find(staff_nick) then
                local lvl_str = tostring(raw_val):match("^([^:]+)") or "1"
                local lvl_num = tonumber(lvl_str) or 1
                
                -- Подставляем нужный цвет прямо перед ником в чате
                local color_prefix = "{22FF22}" -- Зеленый для Юзера
                if lvl_num == 3 then color_prefix = "{FF3333}" -- Красный для Разраба
                elseif lvl_num == 2 then color_prefix = "{FF9900}" -- Оранжевый для Админа
                end
                
                -- Меняем обычный ник на цветной и выводим измененное сообщение
                local new_text = text:gsub(staff_nick, color_prefix .. staff_nick .. "{FFFFFF}")
                -- Перерисовываем строку чата с новыми тегами цвета
                return {color, new_text}
            end
        end
    end
end
function samplua.onShowDialog(dialogId, style, title, button1, button2, text)
    if is_panel_banned then return end
    local lower_title = string.cp1251lower(title)
    local lower_text = string.cp1251lower(text)
    
    if mute_stage > 0 and target_mute_id then
        local final_item = (mute_stage == 1) and 2 or 5 
        lua_thread.create(function()
            wait(200) sampSendDialogResponse(dialogId, 1, final_item, "")
            mute_stage, target_mute_id = 0, nil
        end)
        return false 
    end

    if tp_stage == 1 and (lower_title:find("телепорт") or lower_text:find("мероприяти")) then
        lua_thread.create(function() wait(350) sampSendDialogResponse(dialogId, 1, 1, "") tp_stage = 2 end)
        return false
    end
    if tp_stage == 2 and (lower_title:find("мероприяти") or lower_text:find("небоскр")) then
        lua_thread.create(function() wait(300) sampSendDialogResponse(dialogId, 1, 2, "") tp_stage = 0 end)
        return false
    end
end
