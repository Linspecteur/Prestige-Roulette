let isSpinning = false;
let currentRotation = 0;
let rewardsConfig = [];
let isMuted = false;
let mySpins = 0;
let myMoney = 0;
let pendingWinners = null; // Gagnants en attente d'affichage pendant la rotation
let Locales = {}; // Stockage des traductions

// Fonction pour récupérer une traduction
function _U(key) {
    return Locales[key] || key;
}

// Sons Natifs GTA
const playNativeSound = (soundName) => {
    if (isMuted) return;
    fetch(`https://${GetParentResourceName()}/playSound`, {
        method: 'POST',
        body: JSON.stringify({ sound: soundName })
    }).catch(() => {});
};

// ─── Logique Responsive ──────────────────────────────────────────────────────
function resizeApp() {
    const container = document.querySelector('.main-container');
    if (!container) return;
    
    // Taille de base pour laquelle l'UI a été conçue
    const baseWidth = 1100;
    const baseHeight = 730;
    
    // Taille actuelle de la fenêtre
    const windowWidth = window.innerWidth;
    const windowHeight = window.innerHeight;
    
    // Marge de 90% pour éviter de coller aux bords sur les petits écrans
    const scaleWidth = (windowWidth * 0.9) / baseWidth;
    const scaleHeight = (windowHeight * 0.9) / baseHeight;
    
    // On prend le plus petit scale pour s'assurer que tout rentre
    let scale = Math.min(scaleWidth, scaleHeight);
    
    // On limite le scale max à 1 (ne pas grossir l'UI sur les écrans 4K, sauf si désiré)
    if (scale > 1) scale = 1;
    
    container.style.transform = `scale(${scale})`;
    container.style.transformOrigin = 'center center';
}

// Appliquer au chargement et au redimensionnement
window.addEventListener('resize', resizeApp);
resizeApp();


// ─── NUI Message Handler ─────────────────────────────────────────────────────
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'showOverlay') {
        document.getElementById('overlay').classList.remove('hidden');
    } else if (data.action === 'hideOverlay') {
        document.getElementById('overlay').classList.add('hidden');
    } else if (data.action === 'open') {
        document.getElementById('app').classList.remove('hidden');
        rewardsConfig = data.rewards;
        Locales = data.locale || {}; // Enregistrement de la locale
        applyLocalesToDOM(); // Appliquer aux éléments HTML fixes

        document.getElementById('spin-cost-display').innerText = data.spinCost + '$';
        initWheel(data.rewards);
        if (data.isAdmin) {
            document.getElementById('open-admin-btn').classList.remove('hidden');
        }

    } else if (data.action === 'close') {
        document.getElementById('app').classList.add('hidden');

    } else if (data.action === 'updateStats') {
        updateStats(data.stats);

    } else if (data.action === 'updateWinners') {
        if (isSpinning) {
            // La roue tourne encore — on stocke pour afficher après
            pendingWinners = data.winners;
        } else {
            renderWinners(data.winners);
        }
    }
    
    // Refresh inventory badge if needed
    if (data.action === 'open' || data.action === 'updateStats') {
        refreshInventory();
    }
});

// ─── Application des Locales au DOM ───────────────────────────────────────────
function applyLocalesToDOM() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.getAttribute('data-i18n');
        el.innerText = _U(key);
    });
    document.querySelectorAll('[data-i18n-title]').forEach(el => {
        const key = el.getAttribute('data-i18n-title');
        el.title = _U(key);
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
        const key = el.getAttribute('data-i18n-placeholder');
        el.placeholder = _U(key);
    });
}

// ─── Mise à jour de l'inventaire ─────────────────────────────────────────────
function refreshInventory() {
    fetch(`https://${GetParentResourceName()}/getInventory`, { method: 'POST' })
        .then(r => r.json())
        .then(items => {
            const badge = document.getElementById('inventory-badge');
            if (items && items.length > 0) {
                badge.innerText = items.length;
                badge.classList.remove('hidden');
            } else {
                badge.classList.add('hidden');
            }
            renderInventory(items);
        });
}

function refreshStats() {
    fetch(`https://${GetParentResourceName()}/getStats`, { method: 'POST' })
        .then(r => r.json())
        .then(d => updateStats(d))
        .catch(() => {});
}

function renderInventory(items) {
    const list = document.getElementById('inventory-items-list');
    const count = document.getElementById('inv-count-text');
    count.innerText = items.length;

    if (!items || items.length === 0) {
        list.innerHTML = `<div class="empty-inventory">${_U('ui_empty_inventory')}</div>`;
        return;
    }

    list.innerHTML = items.map((item, index) => `
        <div class="inventory-item" style="animation-delay: ${index * 0.05}s">
            ${item.quantity > 1 ? `<div class="item-quantity-badge">x${item.quantity}</div>` : ''}
            <div class="inv-icon">${getIconForType(item.type)}</div>
            <div class="inv-info">
                <span class="inv-label">${item.label}</span>
                <span class="inv-type">${item.type.replace('_', ' ')}</span>
            </div>
            <div class="inv-actions">
                <button class="btn-claim claim-one" onclick="claimItem('${item.id}', false)">${_U('ui_claim_one')}</button>
                ${item.quantity > 1 ? `<button class="btn-claim claim-all" onclick="claimItem('${item.id}', true)">${_U('ui_claim_all')}</button>` : ''}
            </div>
        </div>
    `).join('');
}

function claimItem(id, claimAll = false) {
    fetch(`https://${GetParentResourceName()}/claimItem`, {
        method: 'POST',
        body: JSON.stringify({ id, claimAll })
    }).then(r => r.json()).then(success => {
        if (success) {
            refreshInventory();
            // Petit délai de sécurité pour s'assurer que la DB est synchro avant le refresh
            setTimeout(() => {
                refreshStats();
            }, 150);
            if (!isMuted) playNativeSound('win');
        }
    });
}

// ─── Initialisation de la roue ───────────────────────────────────────────────
function initWheel(rewards) {
    const wheel = document.getElementById('wheel');
    wheel.innerHTML = '';
    const angleStep = 360 / rewards.length;
    const sliceWidth = Math.tan((angleStep / 2) * Math.PI / 180) * 50;
    // Couleurs par type pour un look plus pro
    const typeColors = {
        'money': '#2ECC71',
        'black_money': '#E74C3C',
        'weapon': '#E67E22',
        'vehicle': '#3498DB',
        'item': '#9B59B6',
        'freespin': '#F1C40F',
        'none': '#34495E'
    };

    rewards.forEach((reward, i) => {
        const segment = document.createElement('div');
        segment.className = 'wheel-segment';
        
        segment.style.setProperty('--i', i);
        segment.style.setProperty('--count', rewards.length);
        segment.style.setProperty('--color', typeColors[reward.type] || '#7F8C8D');
        segment.style.setProperty('--slice-w', (50 + sliceWidth).toFixed(2) + '%');
        segment.style.setProperty('--slice-w-neg', (50 - sliceWidth).toFixed(2) + '%');
        
        segment.innerHTML = `
            <div class="segment-content">
                <div class="segment-icon">${getIconForType(reward.type)}</div>
                <span class="segment-label">${reward.label}</span>
            </div>
        `;
        wheel.appendChild(segment);

        // Ajout d'une ligne de démarcation blanche entre les parts
        const separator = document.createElement('div');
        separator.className = 'separator';
        separator.style.transform = `rotate(${i * angleStep - (angleStep/2)}deg)`;
        wheel.appendChild(separator);
    });
}

function getIconForType(type) {
    switch(type) {
        case 'money':       return '<i class="fa-solid fa-coins" style="color:#F1C40F;"></i>';
        case 'black_money': return '<i class="fa-solid fa-money-bill-wave" style="color:#E74C3C;"></i>';
        case 'weapon':      return '<i class="fa-solid fa-gun" style="color:#E67E22;"></i>';
        case 'vehicle':     return '<i class="fa-solid fa-car" style="color:#3498DB;"></i>';
        case 'item':        return '<i class="fa-solid fa-box" style="color:#9B59B6;"></i>';
        case 'freespin':    return '<i class="fa-solid fa-star" style="color:#F1C40F;"></i>';
        default:            return '<i class="fa-solid fa-xmark" style="color:#95A5A6;"></i>';
    }
}

// ─── Mise à jour des statistiques ────────────────────────────────────────────
function updateStats(data) {
    if (!data) return;
    
    // Stats Globales (seulement si présentes)
    if (data.global) {
        if (data.global.totalSpins !== undefined) document.getElementById('stat-spins').innerText = data.global.totalSpins;
        if (data.global.totalMoneyWon !== undefined) document.getElementById('stat-money').innerText = data.global.totalMoneyWon.toLocaleString() + '$';
        if (data.global.totalVehiclesWon !== undefined) document.getElementById('stat-vehicles').innerText = data.global.totalVehiclesWon;
        if (data.global.totalWeaponsWon !== undefined) document.getElementById('stat-weapons').innerText = data.global.totalWeaponsWon;
    }

    // Stats Personnelles (seulement si présentes)
    if (data.personal) {
        document.getElementById('stat-my-spins').innerText    = data.personal.spins || 0;
        document.getElementById('stat-my-money').innerText    = (data.personal.moneyWon || 0).toLocaleString() + '$';
        document.getElementById('stat-my-weapons').innerText  = data.personal.weaponsWon || 0;
        document.getElementById('stat-my-vehicles').innerText = data.personal.vehiclesWon || 0;
    }

    // Tours Gratuits (seulement si présents dans le message)
    if (data.freeSpins !== undefined) {
        const freeSpins = parseInt(data.freeSpins) || 0;
        const badge = document.getElementById('free-spins-badge');
        const countEl = document.getElementById('free-spins-count');
        
        if (freeSpins > 0) {
            countEl.innerText = freeSpins;
            badge.classList.remove('hidden');
        } else {
            badge.classList.add('hidden');
        }
    }
    
    if (data.winners) {
        if (isSpinning) {
            pendingWinners = data.winners;
        } else {
            renderWinners(data.winners);
        }
    }
}

function renderWinners(winners) {
    const feed = document.getElementById('winners-feed');
    // Sécurité: Si la BDD renvoie {} au lieu de [], Array.isArray permet de ne pas crasher sur le .map()
    if (!winners || !Array.isArray(winners) || winners.length === 0) {
        feed.innerHTML = `<div class="empty-feed">${_U('ui_waiting_winners')}</div>`;
        return;
    }

    feed.innerHTML = winners.map((w, i) => {
        const isNew = i === 0;
        return `
        <div class="winner-item${isNew ? ' winner-new' : ''}">
            <div class="winner-avatar">
                <i class="fa-solid fa-user"></i>
            </div>
            <div class="winner-info">
                <span class="winner-name">${w.name}</span>
                <span class="winner-reward">${w.reward}</span>
            </div>
            <div class="win-icon">${getIconForType(w.type)}</div>
            ${isNew ? '<span class="winner-new-badge">NOUVEAU</span>' : ''}
        </div>`;
    }).join('');
}

// ─── Rotation de la roue ─────────────────────────────────────────────────────
function spinWheel(rewardIndex, rewardData) {
    // Note: isSpinning est déjà mis à true par le bouton spin pour bufferiser les gains
    const wheel = document.getElementById('wheel');
    const spinBtn = document.getElementById('spin-btn');
    spinBtn.disabled = true;

    const angleStep = 360 / rewardsConfig.length;
    const extraSpins = 8 * 360; // 8 tours complets
    
    // On calcule la rotation cible par rapport à la position actuelle
    // pour que la roue continue de tourner dans le même sens sans "sauter"
    const targetAngle = (rewardIndex * angleStep);
    const currentAngle = currentRotation % 360;
    
    let angleDiff = targetAngle - currentAngle;
    if (angleDiff <= 0) angleDiff += 360;
    
    currentRotation += angleDiff + extraSpins;

    wheel.style.transition = 'transform 8s cubic-bezier(0.15, 0, 0.15, 1)';
    wheel.style.transform  = `rotate(-${currentRotation}deg)`;

    if (!isMuted) {
        playNativeSound('spin');
    }

    // --- Logique de "Tick" (son à chaque segment) ---
    let lastSegmentIndex = -1;
    const tickInterval = setInterval(() => {
        if (!isSpinning) {
            clearInterval(tickInterval);
            return;
        }

        // On récupère la rotation actuelle via le style calculé pour être précis
        const style = window.getComputedStyle(wheel);
        const matrix = new WebKitCSSMatrix(style.transform);
        const angle = Math.atan2(matrix.b, matrix.a) * (180 / Math.PI);
        const normalizedAngle = (angle < 0 ? angle + 360 : angle);
        
        const currentSegment = Math.floor(normalizedAngle / angleStep);
        
        if (currentSegment !== lastSegmentIndex) {
            if (!isMuted) {
                playNativeSound('tick');
            }
            lastSegmentIndex = currentSegment;
        }
    }, 20);

    setTimeout(() => {
        const reward = rewardData || rewardsConfig[rewardIndex];
        const hasBanner = (reward && reward.type !== 'none');

        // --- Mise à jour instantanée des stats personnelles & globales ---
        if (reward && reward.type !== 'none') {
            // Incrément Tours (Moi + Serveur)
            const mySpinsEl = document.getElementById('stat-my-spins');
            const srvSpinsEl = document.getElementById('stat-spins');
            mySpinsEl.innerText = (parseInt(mySpinsEl.innerText) || 0) + 1;
            srvSpinsEl.innerText = (parseInt(srvSpinsEl.innerText) || 0) + 1;

            // Incrément Argent gagné (Moi + Serveur)
            if (reward.type === 'money' || reward.type === 'black_money') {
                const myMoneyEl = document.getElementById('stat-my-money');
                const srvMoneyEl = document.getElementById('stat-money');
                
                const myCurrent = parseInt((myMoneyEl.innerText || '0').replace(/[^0-9]/g, '')) || 0;
                const srvCurrent = parseInt((srvMoneyEl.innerText || '0').replace(/[^0-9]/g, '')) || 0;
                
                myMoneyEl.innerText = (myCurrent + reward.value).toLocaleString() + '$';
                srvMoneyEl.innerText = (srvCurrent + reward.value).toLocaleString() + '$';
            }
            
            if (reward.type === 'weapon') {
                const wpEl = document.getElementById('stat-weapons');
                const myWpEl = document.getElementById('stat-my-weapons');
                wpEl.innerText = (parseInt(wpEl.innerText) || 0) + 1;
                myWpEl.innerText = (parseInt(myWpEl.innerText) || 0) + 1;
            }
            if (reward.type === 'vehicle') {
                const vhEl = document.getElementById('stat-vehicles');
                const myVhEl = document.getElementById('stat-my-vehicles');
                vhEl.innerText = (parseInt(vhEl.innerText) || 0) + 1;
                myVhEl.innerText = (parseInt(myVhEl.innerText) || 0) + 1;
            }
        } else if (reward && reward.type === 'none') {
            // On compte quand même le tour
            const mySpinsEl = document.getElementById('stat-my-spins');
            const srvSpinsEl = document.getElementById('stat-spins');
            mySpinsEl.innerText = (parseInt(mySpinsEl.innerText) || 0) + 1;
            srvSpinsEl.innerText = (parseInt(srvSpinsEl.innerText) || 0) + 1;
        }

        // --- Bannière de victoire ---
        if (hasBanner) {
            const banner = document.getElementById('victory-banner');
            document.getElementById('winner-reward-display').innerText = _U('ui_you_won') + reward.label;
            banner.classList.remove('hidden');
            if (!isMuted) playNativeSound('win');
            setTimeout(() => {
                banner.classList.add('hidden');
                isSpinning = false;
                spinBtn.disabled = false;
            }, 4000);
            refreshInventory();
        } else {
            isSpinning = false;
            spinBtn.disabled = false;
        }

        // --- Appliquer les gagnants en attente ---
        if (pendingWinners !== null) {
            renderWinners(pendingWinners);
            pendingWinners = null;
        }

        // --- Sync complète avec le serveur (stats globales + tours gratuits) ---
        refreshStats();

    }, 8500);
}

// ─── Bouton Spin ─────────────────────────────────────────────────────────────
document.getElementById('spin-btn').addEventListener('click', () => {
    if (isSpinning) return;

    // On verrouille IMMÉDIATEMENT avant le fetch
    // pour que tout updateWinners reçu pendant le round-trip réseau
    // soit mis en attente plutôt qu'affiché directement
    isSpinning = true;
    const spinBtn = document.getElementById('spin-btn');
    spinBtn.disabled = true;

    fetch(`https://${GetParentResourceName()}/spin`, { method: 'POST' })
        .then(r => r.json())
        .then(result => {
            if (result && result.index != null) {
                // Diminuer le badge localement tout de suite
                const badge = document.getElementById('free-spins-badge');
                const countEl = document.getElementById('free-spins-count');
                if (!badge.classList.contains('hidden')) {
                    let currentFs = parseInt(countEl.innerText) || 0;
                    if (currentFs > 0) {
                        currentFs--;
                        if (currentFs === 0) badge.classList.add('hidden');
                        else countEl.innerText = currentFs;
                    }
                }
                spinWheel(result.index - 1, result.reward);
            } else {
                // Échec (fonds insuffisants, erreur serveur...)
                isSpinning = false;
                spinBtn.disabled = false;
                const originalText = spinBtn.innerHTML;
                spinBtn.innerText = _U('ui_insufficient_funds');
                spinBtn.style.background = "#c0392b";
                setTimeout(() => {
                    spinBtn.innerHTML = originalText;
                    spinBtn.style.background = "";
                }, 2000);
            }
        }).catch(err => {
            console.error("Erreur lors du spin:", err);
            isSpinning = false;
            spinBtn.disabled = false;
        });
});

// ─── Bouton Fermer ────────────────────────────────────────────────────────────
document.getElementById('close-btn').addEventListener('click', () => {
    document.getElementById('app').classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
});

// ─── Bouton Mute ─────────────────────────────────────────────────────────────
document.getElementById('mute-btn').addEventListener('click', () => {
    isMuted = !isMuted;
    const icon = document.querySelector('#mute-btn i');
    icon.className = isMuted ? 'fa-solid fa-volume-xmark' : 'fa-solid fa-volume-high';
});

// ─── Inventaire ──────────────────────────────────────────────────────────────
document.getElementById('header-inventory-btn').addEventListener('click', () => {
    document.getElementById('inventory-modal').classList.remove('hidden');
    refreshInventory();
});
document.getElementById('close-inventory-btn').addEventListener('click', () => {
    document.getElementById('inventory-modal').classList.add('hidden');
});

// ─── Onglets Stats ───────────────────────────────────────────────────────────
document.getElementById('tab-personal').addEventListener('click', () => {
    document.getElementById('stats-personal').classList.remove('hidden');
    document.getElementById('stats-global').classList.add('hidden');
    document.getElementById('tab-personal').classList.add('active');
    document.getElementById('tab-global').classList.remove('active');
});
document.getElementById('tab-global').addEventListener('click', () => {
    document.getElementById('stats-global').classList.remove('hidden');
    document.getElementById('stats-personal').classList.add('hidden');
    document.getElementById('tab-global').classList.add('active');
    document.getElementById('tab-personal').classList.remove('active');
});


// ─── Effet sonore de clic global ─────────────────────────────────────────────
document.body.addEventListener('click', (e) => {
    const btn = e.target.closest('button') || e.target.closest('.header-action');
    if (btn && btn.id !== 'spin-btn' && !isMuted) {
        playNativeSound('click');
    }
});

// ─── Modal Récompenses (Info) ────────────────────────────────────────────────
document.getElementById('open-info-btn').addEventListener('click', () => {
    const listContainer = document.getElementById('rewards-list-container');
    listContainer.innerHTML = '';
    
    // Calcul de la probabilité totale pour le pourcentage
    const totalProb = rewardsConfig.reduce((acc, r) => acc + r.probability, 0);
    
    // Trier par probabilité (du plus rare au plus commun)
    const sortedRewards = [...rewardsConfig].sort((a, b) => a.probability - b.probability);
    
    sortedRewards.forEach(r => {
        const percent = ((r.probability / totalProb) * 100).toFixed(1);
        const item = document.createElement('div');
        item.className = 'reward-item';
        item.innerHTML = `
            <div class="reward-icon">${getIconForType(r.type)}</div>
            <div class="reward-label">${r.label}</div>
            <div class="reward-prob">${percent}%</div>
        `;
        listContainer.appendChild(item);
    });
    
    document.getElementById('info-modal').classList.remove('hidden');
});
document.getElementById('close-info-btn').addEventListener('click', () => {
    document.getElementById('info-modal').classList.add('hidden');
});

// ─── Modal Code Promo ────────────────────────────────────────────────────────
document.getElementById('open-promo-btn').addEventListener('click', () => {
    document.getElementById('promo-modal').classList.remove('hidden');
});
document.getElementById('cancel-promo-btn').addEventListener('click', () => {
    document.getElementById('promo-modal').classList.add('hidden');
    document.getElementById('promo-message').innerText = '';
});
document.getElementById('apply-promo-btn').addEventListener('click', () => {
    const code = document.getElementById('promo-code-input').value.trim();
    if (!code) return;
    fetch(`https://${GetParentResourceName()}/usePromo`, {
        method: 'POST', body: JSON.stringify({ code })
    }).then(r => r.json()).then(res => {
        const msg = document.getElementById('promo-message');
        if (res.success) {
            msg.style.color = '#2ecc71';
            msg.innerText = _U('ui_promo_success').replace('%s', res.msg);
            refreshStats(); // Mise à jour immédiate du compteur
        } else {
            msg.style.color = '#e74c3c';
            msg.innerText = _U('ui_promo_error').replace('%s', res.msg);
        }
    });
});

// ─── Modal Admin ─────────────────────────────────────────────────────────────
document.getElementById('open-admin-btn').addEventListener('click', () => {
    document.getElementById('admin-modal').classList.remove('hidden');
});
document.getElementById('cancel-admin-btn').addEventListener('click', () => {
    document.getElementById('admin-modal').classList.add('hidden');
});
document.getElementById('admin-give-spins-btn').addEventListener('click', () => {
    const targetId = document.getElementById('admin-target-id').value;
    const amount   = parseInt(document.getElementById('admin-spins-amount').value);
    if (!targetId || !amount) return;
    fetch(`https://${GetParentResourceName()}/adminGiveSpins`, {
        method: 'POST', body: JSON.stringify({ targetId, amount })
    });
});
document.getElementById('admin-create-promo-btn').addEventListener('click', () => {
    const code  = document.getElementById('admin-promo-code').value.trim();
    const spins = parseInt(document.getElementById('admin-promo-spins').value);
    if (!code || !spins) return;
    fetch(`https://${GetParentResourceName()}/adminCreatePromo`, {
        method: 'POST', body: JSON.stringify({ code, spins })
    });
});
let resetConfirmTimer = null;
document.getElementById('admin-reset-stats-btn').addEventListener('click', (e) => {
    if (!resetConfirmTimer) {
        e.target.innerText = "CONFIRMER ?";
        resetConfirmTimer = setTimeout(() => {
            e.target.innerText = _U('ui_admin_reset');
            resetConfirmTimer = null;
        }, 3000);
    } else {
        clearTimeout(resetConfirmTimer);
        resetConfirmTimer = null;
        fetch(`https://${GetParentResourceName()}/adminResetStats`, { method: 'POST' });
        e.target.innerText = _U('ui_admin_reset');
    }
});

document.getElementById('admin-save-webhook-btn').addEventListener('click', () => {
    const url = document.getElementById('admin-webhook-url').value;
    if (!url) return;
    fetch(`https://${GetParentResourceName()}/adminSaveWebhook`, {
        method: 'POST', body: JSON.stringify({ url })
    }).then(() => {
        const msg = document.getElementById('admin-message');
        msg.style.color = '#2ecc71';
        msg.innerText = _U('ui_webhook_saved');
        document.getElementById('admin-webhook-url').value = '';
        setTimeout(() => msg.innerText = '', 3000);
    });
});

// ─── Touche Échap ────────────────────────────────────────────────────────────
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        document.getElementById('app').classList.add('hidden');
        document.getElementById('inventory-modal').classList.add('hidden');
        document.getElementById('promo-modal').classList.add('hidden');
        document.getElementById('admin-modal').classList.add('hidden');
        document.getElementById('info-modal').classList.add('hidden');
        fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
    }
});
