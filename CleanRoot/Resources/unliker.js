//
//  unliker.js
//  cleanroot
//
//  Created by Hüdalfa Bera on 14.05.2026.

(function () {
    // Prevent duplicate execution if injected twice
    if (window.__cleanrootRunning) {
        try {
            window.webkit.messageHandlers.cleanrootBridge.postMessage({
                kind: "log", level: "warning",
                message: "Script is already running — ignoring duplicate start."
            });
        } catch (e) {}
        return;
    }
    window.__cleanrootRunning = true;
    window.__cleanrootShouldStop = false;

    // ---------- Native bridge ----------
    const bridge = {
        post(payload) {
            try {
                window.webkit.messageHandlers.cleanrootBridge.postMessage(payload);
            } catch (e) {
                console.log("[cleanroot bridge unavailable]", payload);
            }
        },
        log(message, level = "info") {
            this.post({ kind: "log", level, message });
        },
        finished(reason) {
            this.post({ kind: "finished", reason });
        }
    };

    // ---------- Cancellable delay ----------
    // Resolves early when stop is requested, so we never block past a cancel.
    const cancellableDelay = (ms) => new Promise((resolve) => {
        const startedAt = Date.now();
        const tick = () => {
            if (window.__cleanrootShouldStop) return resolve();
            if (Date.now() - startedAt >= ms) return resolve();
            setTimeout(tick, Math.min(150, ms));
        };
        tick();
    });

    const randomDelay = (min, max) => {
        const ms = Math.floor(Math.random() * (max - min + 1)) + min;
        return cancellableDelay(ms);
    };

    // Throws a sentinel error that the top-level catch identifies as a clean stop.
    const checkCancelled = () => {
        if (window.__cleanrootShouldStop) {
            const err = new Error("Stopped by user");
            err.__cleanrootStop = true;
            throw err;
        }
    };

    // ---------- Configuration (preserved from original script) ----------
    const DELETION_BATCH_SIZE = 10;
    const MIN_DELAY_ACTIONS = 2000;
    const MAX_DELAY_ACTIONS = 4000;
    const MIN_DELAY_CHECKBOX = 500;
    const MAX_DELAY_CHECKBOX = 1200;
    const MIN_DELAY_AFTER_MODAL = 3000;
    const MAX_DELAY_AFTER_MODAL = 6000;
    const BASE_ERROR_WAIT_MS = 10000;

    let errorStreak = 0;

    const DELETE_BUTTON_TEXTS = ['Delete', 'Löschen', 'Unlike', 'Zurücknehmen', 'Sil', 'Beğenme'];
    const SELECT_BUTTON_TEXTS = ['Select', 'Auswählen', 'Seç'];
    const OK_BUTTON_TEXTS = ['OK', 'Okay', 'Aceptar', 'Tamam'];
    const CHECKBOX_SELECTOR = '[aria-label="Toggle checkbox"]';

    // ---------- DOM helpers ----------
    const clickElement = async (element) => {
        if (!element) return false;
        try {
            element.scrollIntoView({ behavior: 'smooth', block: 'center' });
        } catch (e) {}
        await cancellableDelay(300);
        checkCancelled();
        element.click();
        return true;
    };

    const findSelectButton = async (timeout = 30000) => {
        const startTime = Date.now();
        while (Date.now() - startTime < timeout) {
            checkCancelled();
            const selectButtonSpan = [...document.querySelectorAll('span')]
                .find(el => SELECT_BUTTON_TEXTS.includes(el.textContent.trim()));
            if (selectButtonSpan) return selectButtonSpan.closest('[role="button"]') || selectButtonSpan;
            await cancellableDelay(1000);
        }
        return null;
    };

    const findOkButtonInModal = async (timeout = 5000) => {
        const startTime = Date.now();
        while (Date.now() - startTime < timeout) {
            checkCancelled();
            const okButtonSpan = [...document.querySelectorAll('button, [role="button"], span')]
                .find(el => OK_BUTTON_TEXTS.includes(el.textContent.trim()));
            if (okButtonSpan) {
                const clickableElement = okButtonSpan.closest('button, [role="button"]') || okButtonSpan;
                if (clickableElement.closest('[role="dialog"]')) return clickableElement;
            }
            await cancellableDelay(500);
        }
        return null;
    };

    const deleteSelectedLikes = async () => {
        const deleteButtonSpan = [...document.querySelectorAll('span')]
            .find(el => DELETE_BUTTON_TEXTS.includes(el.textContent.trim()));
        const deleteButton = deleteButtonSpan && (deleteButtonSpan.closest('[role="button"]') || deleteButtonSpan);
        if (!deleteButton) throw new Error('Delete/Unlike button not found');

        await clickElement(deleteButton);
        await randomDelay(MIN_DELAY_ACTIONS, MAX_DELAY_ACTIONS);
        checkCancelled();

        const confirmButton = document.querySelector('button[tabindex="0"]') ||
            [...document.querySelectorAll('button')].find(b => DELETE_BUTTON_TEXTS.includes(b.textContent.trim()));
        if (confirmButton) await clickElement(confirmButton);
    };

    const scrollAndWaitForMoreLikes = async (previousCount) => {
        window.scrollTo(0, document.body.scrollHeight);
        for (let i = 0; i < 15; i++) {
            checkCancelled();
            await cancellableDelay(1000);
            const currentCount = document.querySelectorAll(CHECKBOX_SELECTOR).length;
            if (currentCount > previousCount) return true;
        }
        return false;
    };

    // ---------- Main loop ----------
    const deleteActivity = async () => {
        while (true) {
            checkCancelled();
            bridge.log("⏳ Waiting for next action...", "info");

            const okButton = await findOkButtonInModal(3000);
            if (okButton) {
                errorStreak++;
                const penaltyWait = BASE_ERROR_WAIT_MS * errorStreak;
                bridge.log(`🛑 Rate limit detected! Pressing OK and waiting ${penaltyWait / 1000}s (streak: ${errorStreak})`, "warning");
                await clickElement(okButton);
                await cancellableDelay(penaltyWait);
                continue;
            }

            errorStreak = 0;
            const selectButton = await findSelectButton();
            if (!selectButton) {
                bridge.log("✅ Select button not found. Page may be finished or still loading.", "success");
                break;
            }

            await clickElement(selectButton);
            await randomDelay(MIN_DELAY_ACTIONS, MAX_DELAY_ACTIONS);

            const checkboxes = document.querySelectorAll(CHECKBOX_SELECTOR);
            if (checkboxes.length === 0) {
                bridge.log("🔄 Scrolling for more likes...", "info");
                const gotMore = await scrollAndWaitForMoreLikes(0);
                if (!gotMore) {
                    bridge.log("🎉 No more likes found to delete!", "success");
                    break;
                }
                continue;
            }

            const itemsToSelect = Math.min(DELETION_BATCH_SIZE, checkboxes.length);
            bridge.log(`📌 Selecting ${itemsToSelect} likes...`, "info");

            for (let i = 0; i < itemsToSelect; i++) {
                checkCancelled();
                await clickElement(checkboxes[i]);
                await randomDelay(MIN_DELAY_CHECKBOX, MAX_DELAY_CHECKBOX);
            }

            bridge.log("🗑️ Deleting selected items...", "info");
            await deleteSelectedLikes();
            await randomDelay(MIN_DELAY_AFTER_MODAL, MAX_DELAY_AFTER_MODAL);
            
            // Confirm deletion completed — only NOW we report the count to Swift.
            bridge.log(`✓ Removed ${itemsToSelect} likes.`, "success");
        }
    };

    // ---------- Entry point ----------
    (async () => {
        try {
            bridge.log("🚀 Advanced Mass Unliker started", "system");
            await deleteActivity();
            bridge.log("🏁 Process completed.", "success");
            bridge.finished("completed");
        } catch (error) {
            if (error && error.__cleanrootStop) {
                bridge.log("⏹ Stopped by user.", "warning");
                bridge.finished("stopped");
            } else {
                bridge.log("❌ Fatal script error: " + (error && error.message ? error.message : error), "error");
                bridge.finished("error");
            }
        } finally {
            window.__cleanrootRunning = false;
            window.__cleanrootShouldStop = false;
        }
    })();
})();
