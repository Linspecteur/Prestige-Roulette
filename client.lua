ESX = exports["es_extended"]:getSharedObject()

local isMenuOpen = false

-- Commande principale
RegisterCommand('roulette', function()
    ToggleRouletteMenu()
end, false)

function ToggleRouletteMenu()
    isMenuOpen = not isMenuOpen

    if isMenuOpen then
        -- Check if player is admin before opening
        ESX.TriggerServerCallback('roulette:checkAdmin', function(isAdmin)
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = "open",
                rewards = Config.Rewards,
                spinCost = Config.SpinCost,
                isAdmin = isAdmin,
                locale = Locales[Config.Locale]
            })
            -- Charger les stats
            ESX.TriggerServerCallback('roulette:getStats', function(data)
                SendNUIMessage({
                    action = "updateStats",
                    stats = data
                })
            end)
        end)
    else
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "close" })
    end
end

-- Callback NUI : fermer
RegisterNUICallback('close', function(data, cb)
    isMenuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Callback NUI : rafraîchir les stats (utilisé après promo code, admin actions, etc.)
RegisterNUICallback('getStats', function(data, cb)
    ESX.TriggerServerCallback('roulette:getStats', function(data)
        cb(data)
    end)
end)

-- Callback NUI : jouer un son natif GTA
RegisterNUICallback('playSound', function(data, cb)
    if data.sound == "spin" then
        PlaySoundFrontend(-1, "Spin_Start", "dlc_vw_casino_lucky_wheel_sounds", true)
    elseif data.sound == "tick" then
        PlaySoundFrontend(-1, "Spin_Single_Ticks", "dlc_vw_casino_lucky_wheel_sounds", true)
    elseif data.sound == "win" then
        PlaySoundFrontend(-1, "Win", "dlc_vw_casino_lucky_wheel_sounds", true)
    elseif data.sound == "click" then
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end
    cb('ok')
end)

-- Callback NUI : lancer la roue
RegisterNUICallback('spin', function(data, cb)
    ESX.TriggerServerCallback('roulette:spin', function(result)
        if result then
            cb(result)
        else
            cb({ error = _U('ui_not_enough_money') })
        end
    end)
end)

-- Callback NUI : utiliser un code promo
RegisterNUICallback('usePromo', function(data, cb)
    ESX.TriggerServerCallback('roulette:usePromo', function(success, msg)
        cb({ success = success, msg = msg })
    end, data.code)
end)

-- Callback NUI : actions admin
RegisterNUICallback('getInventory', function(data, cb)
    ESX.TriggerServerCallback('roulette:getInventory', function(items)
        cb(items)
    end)
end)

RegisterNUICallback('claimItem', function(data, cb)
    ESX.TriggerServerCallback('roulette:claimItem', function(success)
        cb(success)
    end, data.id, data.claimAll)
end)

RegisterNUICallback('adminGiveSpins', function(data, cb)
    TriggerServerEvent('roulette:admin:giveSpins', data.targetId, data.amount)
    cb('ok')
end)

RegisterNUICallback('adminCreatePromo', function(data, cb)
    TriggerServerEvent('roulette:admin:createPromo', data.code, data.spins)
    cb('ok')
end)

RegisterNUICallback('adminResetStats', function(data, cb)
    TriggerServerEvent('roulette:admin:resetStats')
    cb('ok')
end)

RegisterNUICallback('adminSaveWebhook', function(data, cb)
    TriggerServerEvent('roulette:admin:saveWebhook', data.url)
    cb('ok')
end)

RegisterNetEvent('roulette:client:updateGlobalStats', function(global)
    SendNUIMessage({
        action = "updateStats",
        stats = { global = global }
    })
end)

-- Mise à jour du feed des gagnants en temps réel
RegisterNetEvent('roulette:client:newWinner')
AddEventHandler('roulette:client:newWinner', function(winners)
    if isMenuOpen then
        SendNUIMessage({ action = "updateWinners", winners = winners })
    end
end)

-- Spawn du véhicule gagné
RegisterNetEvent('roulette:client:spawnVehicle')
AddEventHandler('roulette:client:spawnVehicle', function(model)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do Wait(100) end
    local vehicle = CreateVehicle(GetHashKey(model), coords.x + 3.0, coords.y, coords.z, GetEntityHeading(playerPed), true, false)
    SetPedIntoVehicle(playerPed, vehicle, -1)
    SetEntityAsNoLongerNeeded(vehicle)
end)

-- Gestion de l'affichage cyclique de l'HUD Overlay
CreateThread(function()
    -- Premier affichage à la connexion
    Wait(5000) -- Attend 5 secondes après le chargement
    SendNUIMessage({ action = "showOverlay" })
    Wait(60000) -- Laisse l'overlay pendant 1 minute
    SendNUIMessage({ action = "hideOverlay" })

    -- Cycle : 1 minute toutes les 15 minutes
    while true do
        Wait(900000) -- Attend 15 minutes (15 * 60 * 1000)
        SendNUIMessage({ action = "showOverlay" })
        Wait(60000) -- Affiche pendant 1 minute
        SendNUIMessage({ action = "hideOverlay" })
    end
end)
