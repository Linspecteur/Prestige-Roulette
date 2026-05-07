ESX = exports["es_extended"]:getSharedObject()

local globalStats = {
    totalSpins = 0,
    totalMoneyWon = 0,
    totalVehiclesWon = 0,
    totalWeaponsWon = 0
}

local recentWinners = {}
local playerFreeSpins = {}
local promoCodes = {}

-- ==========================================
-- FONCTIONS WEBHOOK DISCORD
-- ==========================================
-- Fonction pour récupérer l'URL du webhook en direct (KVP ou Config)
local function GetWebhookURL()
    local kvpUrl = GetResourceKvpString("roulette_webhook")
    if kvpUrl and kvpUrl ~= "" then return kvpUrl end
    return Config.Webhook.URL
end

local function SendDiscordLog(playerName, identifier, rewardLabel, rewardType, isJackpot)
    if not Config.Webhook.Enabled then return end
    
    local url = GetWebhookURL()
    if url == "" or url == "YOUR_WEBHOOK_URL_HERE" then return end

    -- Vérifier si on logue ce gain
    if Config.Webhook.OnlyLogBigWins then
        if rewardType ~= "vehicle" and rewardType ~= "weapon" and not isJackpot then
            return
        end
    elseif rewardType == "none" then
        return
    end

    local color = Config.Webhook.Color
    if isJackpot or rewardType == "vehicle" or rewardType == "weapon" then
        color = Config.Webhook.BigWinColor
    end

    local embed = {
        {
            ["color"] = color,
            ["title"] = _U('webhook_title'),
            ["description"] = _U('webhook_desc', playerName, identifier, rewardLabel, rewardType),
            ["footer"] = {
                ["text"] = Config.Webhook.Name .. " • " .. os.date("%Y-%m-%d %H:%M:%S"),
            },
        }
    }

    PerformHttpRequest(url, function(err, text, headers) end, 'POST', json.encode({username = Config.Webhook.Name, embeds = embed, avatar_url = Config.Webhook.AvatarURL}), { ['Content-Type'] = 'application/json' })
end

local function SendAdminLog(source, actionDescription)
    if not Config.Webhook.Enabled then return end
    local url = GetWebhookURL()
    if url == "" or url == "YOUR_WEBHOOK_URL_HERE" then return end

    local xPlayer = ESX.GetPlayerFromId(source)
    local playerName = GetPlayerName(source)
    local identifier = xPlayer and xPlayer.identifier or "N/A"

    local embed = {
        {
            ["color"] = 10181046, -- Violet pour les actions admin
            ["title"] = "🛡️ Action Administrateur",
            ["description"] = string.format("**Admin:** %s\n**Identifier:** %s\n**Action:** %s", playerName, identifier, actionDescription),
            ["footer"] = {
                ["text"] = Config.Webhook.Name .. " • " .. os.date("%Y-%m-%d %H:%M:%S"),
            },
        }
    }
    PerformHttpRequest(url, function(err, text, headers) end, 'POST', json.encode({username = Config.Webhook.Name, embeds = embed, avatar_url = Config.Webhook.AvatarURL}), { ['Content-Type'] = 'application/json' })
end

local function SendClaimLog(source, itemLabel, amount, itemType)
    if not Config.Webhook.Enabled then return end
    local url = GetWebhookURL()
    if url == "" or url == "YOUR_WEBHOOK_URL_HERE" then return end

    local xPlayer = ESX.GetPlayerFromId(source)
    local playerName = GetPlayerName(source)
    local identifier = xPlayer and xPlayer.identifier or "N/A"

    local embed = {
        {
            ["color"] = 3447003, -- Bleu pour la récupération
            ["title"] = "📦 Récupération de Lot",
            ["description"] = string.format("**Joueur:** %s\n**Identifier:** %s\n**A récupéré:** %dx %s\n**Type:** %s", playerName, identifier, amount, itemLabel, itemType),
            ["footer"] = {
                ["text"] = Config.Webhook.Name .. " • " .. os.date("%Y-%m-%d %H:%M:%S"),
            },
        }
    }
    PerformHttpRequest(url, function(err, text, headers) end, 'POST', json.encode({username = Config.Webhook.Name, embeds = embed, avatar_url = Config.Webhook.AvatarURL}), { ['Content-Type'] = 'application/json' })
end

-- ==========================================
-- INITIALISATION MYSQL
-- ==========================================

MySQL.ready(function()
    -- Charger les stats globales
    MySQL.query('SELECT * FROM roulette_global', {}, function(results)
        if results then
            for _, row in ipairs(results) do
                if globalStats[row.name] ~= nil then
                    globalStats[row.name] = row.value
                end
            end
        else
            -- Init if empty
            for name, val in pairs(globalStats) do
                MySQL.insert('INSERT INTO roulette_global (name, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = value', {name, val})
            end
        end
    end)

    -- Charger les derniers gagnants depuis la BDD
    MySQL.query('SELECT * FROM roulette_winners ORDER BY created_at DESC LIMIT 8', {}, function(results)
        if results and #results > 0 then
            recentWinners = {}
            for _, row in ipairs(results) do
                table.insert(recentWinners, { name = row.name, reward = row.reward, type = row.type })
            end
            print("^2[Roulette] ^7" .. #recentWinners .. " gagnants chargés depuis la base de données.")
        else
            print("^3[Roulette] ^7Aucun historique de gagnants trouvé.")
        end
    end)
end)

local function updateGlobalStat(name, value)
    globalStats[name] = value
    MySQL.update('UPDATE roulette_global SET value = ? WHERE name = ?', {value, name})
    -- Synchroniser avec tous les clients en ligne
    TriggerClientEvent('roulette:client:updateGlobalStats', -1, globalStats)
end

local function getPlayerStats(identifier, cb)
    MySQL.single('SELECT * FROM roulette_players WHERE identifier = ?', {identifier}, function(result)
        if result then
            cb(result)
        else
            local default = {spins = 0, money_won = 0, free_spins = 0}
            MySQL.insert('INSERT INTO roulette_players (identifier, spins, money_won, free_spins) VALUES (?, ?, ?, ?)', 
                {identifier, 0, 0, 0})
            cb(default)
        end
    end)
end

-- ==========================================
-- FONCTIONS ADMINISTRATEUR (NUI)
-- ==========================================

ESX.RegisterServerCallback('roulette:checkAdmin', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end
    local group = xPlayer.getGroup()
    local isAdmin = false
    for _, g in ipairs(Config.AdminGroups) do
        if group == g then isAdmin = true break end
    end
    cb(isAdmin)
end)

RegisterNetEvent('roulette:admin:giveSpins')
AddEventHandler('roulette:admin:giveSpins', function(targetId, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local group = xPlayer.getGroup()
    local isAdmin = false
    for _, g in ipairs(Config.AdminGroups) do
        if group == g then isAdmin = true break end
    end
    if not isAdmin then return end

    local xTarget = ESX.GetPlayerFromId(tonumber(targetId))
    if xTarget then
        playerFreeSpins[xTarget.identifier] = (playerFreeSpins[xTarget.identifier] or 0) + amount
        MySQL.update('UPDATE roulette_players SET free_spins = free_spins + ? WHERE identifier = ?', {amount, xTarget.identifier})
        TriggerClientEvent('esx:showNotification', tonumber(targetId), _U('received_spins', amount))
        SendAdminLog(src, string.format("A donné %s tour(s) au joueur ID %s (%s)", amount, targetId, GetPlayerName(targetId)))
    end
end)

RegisterNetEvent('roulette:admin:createPromo')
AddEventHandler('roulette:admin:createPromo', function(code, spins)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local group = xPlayer.getGroup()
    local isAdmin = false
    for _, g in ipairs(Config.AdminGroups) do
        if group == g then isAdmin = true break end
    end
    if not isAdmin then return end
    promoCodes[string.upper(code)] = { spins = spins, used = {} }
    TriggerClientEvent('esx:showNotification', src, _U('promo_created', code))
    SendAdminLog(src, string.format("A créé le code promo `%s` pour %s tour(s)", code, spins))
end)

RegisterNetEvent('roulette:admin:resetStats')
AddEventHandler('roulette:admin:resetStats', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local group = xPlayer.getGroup()
    local isAdmin = false
    for _, g in ipairs(Config.AdminGroups) do
        if group == g then isAdmin = true break end
    end
    if not isAdmin then return end
    
    globalStats = { totalSpins = 0, totalMoneyWon = 0, totalVehiclesWon = 0, totalWeaponsWon = 0 }
    for name, val in pairs(globalStats) do
        MySQL.update('UPDATE roulette_global SET value = 0 WHERE name = ?', {name})
    end
    
    recentWinners = {}
    MySQL.query('DELETE FROM roulette_winners', {}) -- Plus sûr que TRUNCATE sur certains serveurs
    
    -- Synchroniser avec TOUT le monde immédiatement
    TriggerClientEvent('roulette:client:updateGlobalStats', -1, globalStats)
    TriggerClientEvent('roulette:client:newWinner', -1, recentWinners)
    
    TriggerClientEvent('esx:showNotification', src, _U('stats_reset'))
    SendAdminLog(src, "A réinitialisé les statistiques globales de la roulette.")
end)

RegisterNetEvent('roulette:admin:saveWebhook')
AddEventHandler('roulette:admin:saveWebhook', function(url)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local isAdmin = false
    for _, group in ipairs(Config.AdminGroups) do
        if xPlayer.getGroup() == group then
            isAdmin = true
            break
        end
    end
    if not isAdmin then return end
    
    SetResourceKvp("roulette_webhook", url)
    SendAdminLog(src, "A modifié l'URL du Webhook Discord depuis le panel en jeu.")
end)

-- ==========================================
-- CALLBACKS PRINCIPAUX
-- ==========================================

ESX.RegisterServerCallback('roulette:getStats', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({global = globalStats, winners = recentWinners, freeSpins = 0, personal = {}}) end

    getPlayerStats(xPlayer.identifier, function(pStats)
        playerFreeSpins[xPlayer.identifier] = pStats.free_spins
        cb({
            global = globalStats,
            winners = recentWinners,
            freeSpins = pStats.free_spins,
            personal = {
                spins = pStats.spins or 0,
                moneyWon = pStats.money_won or 0,
                weaponsWon = pStats.weapons_won or 0,
                vehiclesWon = pStats.vehicles_won or 0
            }
        })
    end)
end)

ESX.RegisterServerCallback('roulette:usePromo', function(source, cb, code)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false, "Erreur") end
    local promo = promoCodes[string.upper(code)]
    if not promo then return cb(false, _U('invalid_code')) end
    
    for _, id in ipairs(promo.used) do
        if id == xPlayer.identifier then return cb(false, _U('code_used')) end
    end
    
    table.insert(promo.used, xPlayer.identifier)
    playerFreeSpins[xPlayer.identifier] = (playerFreeSpins[xPlayer.identifier] or 0) + promo.spins
    
    MySQL.update('UPDATE roulette_players SET free_spins = free_spins + ? WHERE identifier = ?', {promo.spins, xPlayer.identifier}, function()
        cb(true, promo.spins)
    end)
end)

local function addToInventory(identifier, reward)
    MySQL.single('SELECT id FROM roulette_inventory WHERE identifier = ? AND label = ? AND value = ? AND type = ?', 
        {identifier, reward.label, tostring(reward.value), reward.type}, function(existing)
        if existing then
            MySQL.update('UPDATE roulette_inventory SET quantity = quantity + 1 WHERE id = ?', {existing.id})
        else
            local id = ESX.GetRandomString(10)
            MySQL.insert('INSERT INTO roulette_inventory (id, identifier, label, value, type, quantity) VALUES (?, ?, ?, ?, ?, ?)', 
                {id, identifier, reward.label, tostring(reward.value), reward.type, 1})
        end
    end)
end

ESX.RegisterServerCallback('roulette:getInventory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    MySQL.query('SELECT * FROM roulette_inventory WHERE identifier = ? ORDER BY created_at DESC', {xPlayer.identifier}, function(results)
        cb(results or {})
    end)
end)

ESX.RegisterServerCallback('roulette:claimItem', function(source, cb, id, claimAll)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    MySQL.single('SELECT * FROM roulette_inventory WHERE id = ? AND identifier = ?', {id, xPlayer.identifier}, function(item)
        if item then
            local amountToClaim = 1
            if claimAll then amountToClaim = item.quantity end
            
            local success = false
            if item.type == "money" then
                xPlayer.addMoney(tonumber(item.value) * amountToClaim)
                success = true
            elseif item.type == "black_money" then
                xPlayer.addAccountMoney('black_money', tonumber(item.value) * amountToClaim)
                success = true
            elseif item.type == "weapon" then
                -- Les armes ne se stackent pas vraiment dans l'inventaire ESX standard, on en donne une par une ou via une boucle
                for i=1, amountToClaim do
                    xPlayer.addWeapon(item.value, 100)
                end
                success = true
            elseif item.type == "vehicle" then
                -- Spawn des véhicules un par un
                for i=1, amountToClaim do
                    TriggerClientEvent('roulette:client:spawnVehicle', source, item.value)
                end
                success = true
            elseif item.type == "item" then
                xPlayer.addInventoryItem(item.value, amountToClaim)
                success = true
            end

            local function finalizeClaim()
                if claimAll or item.quantity <= 1 then
                    MySQL.update('DELETE FROM roulette_inventory WHERE id = ?', {id}, function()
                        SendClaimLog(source, item.label, amountToClaim, item.type)
                        cb(true)
                    end)
                else
                    MySQL.update('UPDATE roulette_inventory SET quantity = quantity - 1 WHERE id = ?', {id}, function()
                        SendClaimLog(source, item.label, 1, item.type)
                        cb(true)
                    end)
                end
            end

            if item.type == "freespin" then
                MySQL.update('UPDATE roulette_players SET free_spins = free_spins + ? WHERE identifier = ?', 
                    {(tonumber(item.value) or 1) * amountToClaim, xPlayer.identifier}, function()
                    finalizeClaim()
                end)
            elseif success then
                finalizeClaim()
            else
                cb(false)
            end
        else
            cb(false)
        end
    end)
end)

ESX.RegisterServerCallback('roulette:spin', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end

    getPlayerStats(xPlayer.identifier, function(pStats)
        local freeSpins = pStats.free_spins

        if freeSpins > 0 then
            MySQL.update('UPDATE roulette_players SET free_spins = free_spins - 1 WHERE identifier = ?', {xPlayer.identifier})
        elseif xPlayer.getMoney() >= Config.SpinCost then
            xPlayer.removeMoney(Config.SpinCost)
            MySQL.update('UPDATE roulette_players SET money_spent = money_spent + ? WHERE identifier = ?', {Config.SpinCost, xPlayer.identifier})
        else
            return cb(nil)
        end

        -- Tirage pondéré
        local totalWeight = 0
        for _, r in ipairs(Config.Rewards) do totalWeight = totalWeight + r.probability end
        local roll = math.random(1, totalWeight)
        local cumul = 0
        local winner = Config.Rewards[1]
        for _, r in ipairs(Config.Rewards) do
            cumul = cumul + r.probability
            if roll <= cumul then winner = r break end
        end

        -- Maj stats globales
        updateGlobalStat('totalSpins', globalStats.totalSpins + 1)
        MySQL.update('UPDATE roulette_players SET spins = spins + 1 WHERE identifier = ?', {xPlayer.identifier})

        -- On ne donne PAS le gain tout de suite, on le met en inventaire (sauf si c'est "rien")
        if winner.type ~= "none" then
            addToInventory(xPlayer.identifier, winner)
            
            -- On met à jour les stats de gains quand même pour le scoreboard
            if winner.type == "money" or winner.type == "black_money" then
                updateGlobalStat('totalMoneyWon', globalStats.totalMoneyWon + winner.value)
                MySQL.update('UPDATE roulette_players SET money_won = money_won + ? WHERE identifier = ?', {winner.value, xPlayer.identifier})
            elseif winner.type == "weapon" then
                updateGlobalStat('totalWeaponsWon', globalStats.totalWeaponsWon + 1)
                MySQL.update('UPDATE roulette_players SET weapons_won = weapons_won + 1 WHERE identifier = ?', {xPlayer.identifier})
            elseif winner.type == "vehicle" then
                updateGlobalStat('totalVehiclesWon', globalStats.totalVehiclesWon + 1)
                MySQL.update('UPDATE roulette_players SET vehicles_won = vehicles_won + 1 WHERE identifier = ?', {xPlayer.identifier})
            end

            -- Ajout au feed des gagnants
            table.insert(recentWinners, 1, { name = xPlayer.getName(), reward = winner.label, type = winner.type })
            if #recentWinners > 8 then table.remove(recentWinners) end
            
            -- Sauvegarde BDD
            MySQL.insert('INSERT INTO roulette_winners (name, reward, type) VALUES (?, ?, ?)', 
                {xPlayer.getName(), winner.label, winner.type})

            TriggerClientEvent('roulette:client:newWinner', -1, recentWinners)
            
            -- Discord Webhook Log
            local isJackpot = (winner.label:find("JACKPOT") ~= nil)
            SendDiscordLog(xPlayer.getName(), xPlayer.identifier, winner.label, winner.type, isJackpot)
        end

        local rewardIndex = 1
        for i, r in ipairs(Config.Rewards) do
            if r.label == winner.label then rewardIndex = i break end
        end

        cb({ index = rewardIndex, reward = winner })
    end)
end)


