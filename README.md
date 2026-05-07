<div align="center">
  <img src="https://img.shields.io/badge/FiveM-Script-orange?style=for-the-badge&logo=fivem&logoColor=white" />
  <img src="https://img.shields.io/badge/Framework-ESX-blue?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Author-Linspecteur-purple?style=for-the-badge" />
  
  <h1>🎰 Prestige Roulette (br_rlte)</h1>
  <p><i>L'expérience de casino ultime pour votre serveur FiveM</i></p>
</div>

---

## 📖 À propos

**Prestige Roulette** n'est pas un simple script de jeu. C'est une immersion complète dans l'univers du luxe. Conçu avec une approche moderne et épurée, il transforme votre serveur en un véritable établissement de haut standing grâce à son interface **Glassmorphism** et ses mécaniques fluides.

---

## 🌟 Fonctionnalités Clés

- 🎨 **Interface Premium (UI) :** Design moderne, réactif et élégant s'adaptant à toutes les résolutions d'écran.
- 📦 **Système de "Mes Lots" :** Un inventaire casino dédié. Les joueurs gagnent, stockent et réclament leurs récompenses quand ils le souhaitent.
- 📈 **Statistiques Live :** Suivi en temps réel des performances personnelles et globales du serveur.
- 🏆 **Winner Feed :** Un fil d'actualité en direct pour afficher les derniers grands gagnants de la communauté.
- 🎟️ **Codes Promotionnels :** Créez des codes personnalisés pour offrir des tours gratuits à vos joueurs.
- 🔧 **Admin Panel Intégré :** Gérez tout depuis l'interface (give tours, reset stats, management des codes).
- 🔊 **Audio Immersif :** Effets sonores intégrés pour une immersion totale.
- 🌍 **Multi-langues (i18n) :** Support complet du Français (FR) et de l'Anglais (EN) avec bascule instantanée.
- 🤖 **Logs Discord :** Webhook paramétrable pour surveiller les jackpots et les gains importants.

---

## ⚙️ Prérequis

Pour fonctionner de manière optimale, le script nécessite :
- [**es_extended**](https://github.com/esx-framework/esx-legacy) (Framework ESX)
- [**oxmysql**](https://github.com/overextended/oxmysql) (Gestion de la base de données)

---

## 📥 Installation

1. **Extraction :** Placez le dossier dans le répertoire `resources` de votre serveur.
2. **Renommage :** Assurez-vous que le dossier se nomme exactement `br_rlte`.
3. **Base de données :** Importez le fichier `install.sql` dans votre base de données.
4. **Configuration :** Modifiez le fichier `config.lua` (Webhook, récompenses, prix du tour).
5. **Démarrage :** Ajoutez `ensure br_rlte` dans votre `server.cfg`.

---

## 🛠️ Configuration (`config.lua`)

Le fichier de configuration est structuré pour une personnalisation rapide :

```lua
Config.Locale = 'fr' -- 'fr' ou 'en'
Config.Webhook = "VOTRE_WEBHOOK_ICI"
Config.AdminGroups = { 'admin', 'superadmin' }
```

> [!TIP]
> Vous pouvez configurer des probabilités précises pour chaque item dans la table `Config.Rewards`. Plus le poids est bas, plus l'item est rare !

---

## 🕹️ Commandes

- `/roulette` : Ouvre l'interface de jeu.
- **Panel Admin :** Accessible via le bouton dédié dans l'interface (réservé aux groupes définis dans la config).

---

## 🔗 Liens & Support

Besoin d'aide ou envie de découvrir d'autres projets ?

🔑 **Téléchargement :** [Discord Community](https://discord.gg/9UBX75M4gU)  
🎏 **Twitter :** [@Linspecteuur](https://twitter.com/Linspecteuur)  
👨‍🎓 **Profile Steam :** [Linspecteur](https://steamcommunity.com/id/inspectorese/)  
💫 **Contact Pro :** linspecteur.pro@gmail.com

---

<div align="center">
  <p>Développé avec passion par <b>Linspecteur</b></p>
</div>
