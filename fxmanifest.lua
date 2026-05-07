fx_version 'cerulean'
game 'gta5'

name 'br_rlte'
author 'Linspecteur'
description 'Luxury Roulette - Casino Script FiveM'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'locales/fr.lua',
    'locales/en.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
