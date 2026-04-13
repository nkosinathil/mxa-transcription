/**
 * php-app/public/assets/js/app.js
 * ---------------------------------
 * Minimal JavaScript for the web UI.
 * No framework dependencies – just vanilla JS.
 */

/* ------------------------------------------------------------------ */
/* Sidebar toggle (mobile)                                              */
/* ------------------------------------------------------------------ */
const sidebarToggle = document.getElementById('sidebarToggle');
const sidebar       = document.getElementById('sidebar');

if (sidebarToggle && sidebar) {
    sidebarToggle.addEventListener('click', () => {
        sidebar.classList.toggle('open');
    });

    // Close sidebar on outside click (mobile)
    document.addEventListener('click', e => {
        if (sidebar.classList.contains('open') &&
            !sidebar.contains(e.target) &&
            e.target !== sidebarToggle) {
            sidebar.classList.remove('open');
        }
    });
}

/* ------------------------------------------------------------------ */
/* Auto-dismiss flash alerts after 5 seconds                           */
/* ------------------------------------------------------------------ */
document.querySelectorAll('.alert').forEach(el => {
    setTimeout(() => {
        el.style.transition = 'opacity .4s';
        el.style.opacity    = '0';
        setTimeout(() => el.remove(), 400);
    }, 5000);
});

/* ------------------------------------------------------------------ */
/* Confirm dangerous actions (forms with data-confirm attribute)       */
/* ------------------------------------------------------------------ */
document.querySelectorAll('[data-confirm]').forEach(el => {
    el.addEventListener('click', e => {
        if (!window.confirm(el.dataset.confirm)) {
            e.preventDefault();
        }
    });
});
