/* MULTIcoroner page. Based on phils-coroner by Phil. Part of MULTIcore (GPL v3). */
(function () {
    'use strict';

    var RESOURCE = typeof window.GetParentResourceName === 'function' ? window.GetParentResourceName() : 'MULTIcoroner';
    var T = {};

    function post(name, data) {
        return fetch('https://' + RESOURCE + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).catch(function () {});
    }

    function $(id) { return document.getElementById(id); }

    // one line of text; %s markers are filled in order
    function t(key) {
        var text = T[key] != null ? String(T[key]) : key;
        for (var i = 1; i < arguments.length; i++) text = text.replace('%s', String(arguments[i]));
        return text;
    }

    function applyText(data) {
        if (data && data.text) T = data.text;
        document.querySelectorAll('[data-t]').forEach(function (el) { el.textContent = t(el.getAttribute('data-t')); });
        document.querySelectorAll('[data-ph]').forEach(function (el) { el.placeholder = t(el.getAttribute('data-ph')); });
        if (data && data.lang) {
            ui.classList.toggle('mc-cyrillic', data.lang === 'ru');
            toastStack.classList.toggle('mc-cyrillic', data.lang === 'ru');
        }
    }

    var ui = $('ui');
    var casePanel = $('case-panel');
    var reportsPanel = $('reports-panel');
    var detailPanel = $('detail-panel');
    var reportsList = $('reports-list');
    var toastStack = $('toasts');

    var subjectName = $('subject-name');
    var subjectLocation = $('subject-location');
    var cause = $('cause-of-death');
    var manner = $('manner-of-death');
    var notes = $('inquest-notes');
    var conclusion = $('conclusion');

    var caseData = null;
    var reports = [];
    var detailReport = null;
    var detailReturnTo = 'reports';
    var detailCanManage = true;
    var deleteArmed = false;
    var deleteArmTimer = null;

    function typeLabel(type) { return t('type_' + (type || 'NPC')); }
    function mannerLabel(code) { return code ? t('manner_' + code) : t('manner_UNDETERMINED'); }

    function showPanel(panel) {
        [casePanel, reportsPanel, detailPanel].forEach(function (p) { p.classList.toggle('mc-hidden', p !== panel); });
        ui.classList.remove('mc-hidden');
    }

    function setText(id, value, fallbackKey) {
        $(id).textContent = value == null || value === '' ? t(fallbackKey || 'not_recorded') : String(value);
    }

    function updateCompleteness() {
        var checks = [subjectName.value.trim() !== '', cause.value.trim() !== '', conclusion.value.trim() !== ''];
        var done = checks.filter(Boolean).length;
        $('completeness-fill').style.width = Math.round(done / checks.length * 100) + '%';
    }

    function populateManners(values) {
        manner.innerHTML = '';
        (Array.isArray(values) && values.length ? values : ['UNDETERMINED']).forEach(function (code) {
            var option = document.createElement('option');
            option.value = code;
            option.textContent = mannerLabel(code);
            manner.appendChild(option);
        });
        manner.value = 'UNDETERMINED';
        if (!manner.value && manner.options.length) manner.selectedIndex = 0;
    }

    function openCase(data) {
        caseData = data.caseData || {};
        $('subject-type').textContent = typeLabel(caseData.type);
        $('case-time').textContent = data.time || '';
        populateManners(data.manners);
        subjectName.value = caseData.identifiedName || caseData.name || '';
        subjectLocation.value = caseData.location || '';
        cause.value = '';
        notes.value = '';
        conclusion.value = '';
        updateCompleteness();
        showPanel(casePanel);
        window.setTimeout(function () { (subjectName.value ? cause : subjectName).focus(); }, 40);
    }

    function renderReports(list) {
        reportsList.innerHTML = '';
        if (!list.length) {
            var empty = document.createElement('div');
            empty.className = 'cr-empty';
            empty.textContent = t('no_reports');
            reportsList.appendChild(empty);
            return;
        }
        list.slice().reverse().forEach(function (report) {
            var row = document.createElement('div');
            row.className = 'mc-row cr-row';
            row.tabIndex = 0;

            var top = document.createElement('div');
            top.className = 'cr-row-top';
            var title = document.createElement('span');
            title.textContent = (report.id || '') + '  ·  ' + (report.subjectNameForm || report.subjectName || t('unidentified'));
            var time = document.createElement('span');
            time.className = 'cr-row-time';
            time.textContent = report.time || '';
            top.appendChild(title);
            top.appendChild(time);

            var sub = document.createElement('div');
            sub.className = 'mc-sub';
            sub.textContent = typeLabel(report.subjectType) + '  ·  ' + (report.cause || t('cause_unrecorded')) + '  ·  ' +
                mannerLabel(report.manner) + '  ·  ' + t('filed_by', report.coroner || t('unknown'));

            row.appendChild(top);
            row.appendChild(sub);
            row.addEventListener('click', function () { openReportDetail(report, 'reports', true); });
            row.addEventListener('keydown', function (e) {
                if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openReportDetail(report, 'reports', true); }
            });
            reportsList.appendChild(row);
        });
    }

    function openReports(list) {
        reports = Array.isArray(list) ? list : [];
        renderReports(reports);
        showPanel(reportsPanel);
    }

    function resetDeleteButton() {
        deleteArmed = false;
        if (deleteArmTimer) { window.clearTimeout(deleteArmTimer); deleteArmTimer = null; }
        var btn = $('detail-delete');
        btn.textContent = t('btn_delete');
        btn.classList.remove('armed');
    }

    function openReportDetail(report, returnTo, canManage) {
        detailReport = report || {};
        detailReturnTo = returnTo || 'reports';
        detailCanManage = canManage === true;
        resetDeleteButton();

        $('detail-print').style.display = detailCanManage ? '' : 'none';
        $('detail-delete').style.display = detailCanManage ? '' : 'none';

        setText('detail-id', detailReport.id);
        setText('detail-time', detailReport.time, 'unknown');
        setText('detail-coroner', detailReport.coroner, 'unknown');
        $('detail-type').textContent = typeLabel(detailReport.subjectType);
        setText('detail-recorded-name', detailReport.subjectName, 'unidentified');
        setText('detail-identified-name', detailReport.subjectNameForm, 'unidentified');
        setText('detail-location', detailReport.location);
        setText('detail-cause', detailReport.cause, 'cause_unrecorded');
        $('detail-manner').textContent = mannerLabel(detailReport.manner);
        setText('detail-notes', detailReport.notes);
        setText('detail-conclusion', detailReport.conclusion);

        showPanel(detailPanel);
    }

    function hideAll() {
        ui.classList.add('mc-hidden');
        [casePanel, reportsPanel, detailPanel].forEach(function (p) { p.classList.add('mc-hidden'); });
        caseData = null;
        detailReport = null;
        resetDeleteButton();
    }

    function closeUI() {
        hideAll();
        post('close');
    }

    function handleBack() {
        if (!detailPanel.classList.contains('mc-hidden') && detailReturnTo === 'reports') {
            showPanel(reportsPanel);
            return;
        }
        closeUI();
    }

    function toast(type, label, message) {
        var el = document.createElement('div');
        el.className = 'cr-toast ' + (type || 'info');
        var l = document.createElement('div');
        l.className = 'cr-toast-label';
        l.textContent = label || '';
        var m = document.createElement('div');
        m.className = 'cr-toast-message';
        m.textContent = message || '';
        el.appendChild(l);
        el.appendChild(m);
        toastStack.appendChild(el);
        window.requestAnimationFrame(function () { el.classList.add('visible'); });
        window.setTimeout(function () {
            el.classList.remove('visible');
            window.setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 300);
        }, 4500);
    }

    function fileReport() {
        if (!caseData) return toast('error', t('t_failed'), t('m_inactive'));
        if (!cause.value.trim() || !conclusion.value.trim()) return toast('error', t('t_failed'), t('m_need_cause'));
        post('submit', {
            subjectName: subjectName.value,
            cause: cause.value,
            manner: manner.value,
            notes: notes.value,
            conclusion: conclusion.value
        });
        hideAll();
    }

    // ---------- buttons ----------
    [subjectName, cause, conclusion].forEach(function (f) { f.addEventListener('input', updateCompleteness); });

    $('case-cancel').addEventListener('click', closeUI);
    $('btn-file').addEventListener('click', fileReport);
    $('reports-close').addEventListener('click', closeUI);
    $('reports-refresh').addEventListener('click', function () { post('getReports'); });
    $('detail-done').addEventListener('click', handleBack);

    $('detail-print').addEventListener('click', function () {
        if (!detailReport || !detailReport.id) return;
        post('printReport', { reportId: detailReport.id });
        toast('info', t('t_printing'), t('m_printing', detailReport.id));
    });

    $('detail-delete').addEventListener('click', function () {
        if (!detailReport || !detailReport.id || !detailCanManage) return;
        var btn = $('detail-delete');
        if (!deleteArmed) {
            deleteArmed = true;
            btn.textContent = t('btn_confirm_delete');
            btn.classList.add('armed');
            toast('warn', t('t_confirm'), t('m_confirm', detailReport.id));
            deleteArmTimer = window.setTimeout(resetDeleteButton, 4000);
            return;
        }
        var deletedId = detailReport.id;
        resetDeleteButton();
        post('deleteReport', { reportId: deletedId });
        reports = reports.filter(function (r) { return r.id !== deletedId; });
        detailReport = null;
        renderReports(reports);
        showPanel(reportsPanel);
        post('getReports');
    });

    // Esc closes (or goes back from a report to the ledger). Backspace is left alone so typing works.
    document.addEventListener('keydown', function (e) {
        if (e.key !== 'Escape' || ui.classList.contains('mc-hidden')) return;
        e.preventDefault();
        if (!detailPanel.classList.contains('mc-hidden')) return handleBack();
        closeUI();
    });

    // ---------- messages from Lua ----------
    window.addEventListener('message', function (event) {
        var data = event.data || {};
        switch (data.action) {
            case 'openCase': applyText(data); openCase(data); break;
            case 'openReports': applyText(data); openReports(data.reports); break;
            case 'openReportDetail': applyText(data); openReportDetail(data.report, data.fromItem ? 'item' : 'reports', data.canManage); break;
            case 'close': hideAll(); break;
            case 'toast': toast(data.type, data.label, data.message); break;
        }
    });
})();
