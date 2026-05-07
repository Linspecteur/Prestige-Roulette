Config = {}

Config.Locale = 'fr'

function _U(str, ...)
    local locale = Config.Locale
    if not Locales or not Locales[locale] then return "Translation missing: " .. str end
    if not Locales[locale][str] then return "Translation missing: " .. str end
    return string.format(Locales[locale][str], ...)
end

Config.SpinCost = 5000
Config.AdminGroups = { 'admin', 'superadmin' }

Config.Webhook = {
    Enabled = true,
    URL = "YOUR_WEBHOOK_URL_HERE", -- Remplacé automatiquement si un admin le configure en jeu
    Name = "Prestige Roulette Logs",
    AvatarURL = "https://i.imgur.com/K3pUa5j.png", -- Optionnel : URL d'une image pour le bot
    Color = 15158332, -- Couleur de base (Or/Jaune)
    BigWinColor = 15158332, -- Couleur pour les gros gains
    -- Si true, ne log que les véhicules, armes, jackpot. Si false, log tous les gains (sauf "rien").
    OnlyLogBigWins = false 
}

Config.Rewards = {
    { label = "5.000$",          value = 5000,              type = "money",       probability = 150 },
    { label = "Kit de Soin",     value = "medikit",         type = "item",        probability = 120 },
    { label = "Rien du tout",    value = nil,               type = "none",        probability = 100 },
    { label = "10.000$",         value = 10000,             type = "money",       probability = 80  },
    { label = "Pistolet",        value = "weapon_pistol",   type = "weapon",      probability = 60  },
    { label = "Argent Sale",     value = 8000,              type = "black_money", probability = 50  },
    { label = "+1 Tour",         value = 1,                 type = "freespin",    probability = 40  },
    { label = "Fusil Assault",   value = "weapon_assaultrifle", type = "weapon",  probability = 20  },
    { label = "50.000$",         value = 50000,             type = "money",       probability = 10  },
    { label = "Voiture VIP",     value = "adder",           type = "vehicle",     probability = 5   },
    { label = "Bien du tout",    value = nil,               type = "none",        probability = 90  },
    { label = "JACKPOT 250K$",   value = 250000,            type = "money",       probability = 1   },
}
