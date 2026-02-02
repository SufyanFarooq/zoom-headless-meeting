const API_BASE_URL = (window.location.hostname === 'localhost' && window.location.port === '8080')
    ? 'http://localhost:3000/api' : '/api';

function fetchWithAuth(url, options = {}) {
    const token = localStorage.getItem('authToken');
    const headers = { 'Content-Type': 'application/json', ...options.headers };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    return fetch(url, { ...options, headers }).then(r => {
        if (r.status === 401) {
            localStorage.removeItem('authToken');
            window.location.href = 'login.html';
            return Promise.reject(new Error('Unauthorized'));
        }
        return r;
    });
}

window.addEventListener('DOMContentLoaded', () => {
    if (!localStorage.getItem('authToken')) {
        window.location.href = 'login.html';
        return;
    }
    refreshNamesFilesList();
});

let currentNamesFile = null;
let namesContentDirty = false;

async function refreshNamesFilesList() {
    try {
        const r = await fetchWithAuth(`${API_BASE_URL}/names/files?withCounts=1`);
        const d = await r.json();
        const files = d.files || [];
        const ul = document.getElementById('namesFilesList');
        if (files.length === 0) {
            ul.innerHTML = '<li class="empty">No files. Click New File to create one.</li>';
        } else {
            ul.innerHTML = files.map(f => {
                const name = f.name || f;
                const count = (typeof f === 'object' && f.count != null) ? f.count : '-';
                const active = name === currentNamesFile ? ' active' : '';
                return `<li class="${active}" onclick="selectNamesFile('${String(name).replace(/'/g, "\\'")}')">
                    <span>${name}</span>
                    <span class="file-count">${count} names</span>
                </li>`;
            }).join('');
        }
        if (files.length && !currentNamesFile) {
            const first = files[0].name || files[0];
            selectNamesFile(first);
        }
    } catch (e) {
        document.getElementById('namesFilesList').innerHTML = '<li class="empty">Error loading files</li>';
    }
}

function updateNamesCount() {
    const content = document.getElementById('namesContent').value || '';
    const lines = content.split('\n').filter(l => l.trim() && !l.trim().startsWith('#'));
    document.getElementById('namesCount').textContent = lines.length;
}

async function selectNamesFile(name) {
    if (namesContentDirty && !confirm('Save changes before switching?')) return;
    currentNamesFile = name;
    try {
        const r = await fetchWithAuth(`${API_BASE_URL}/names/files/${encodeURIComponent(name)}`);
        const d = await r.json();
        const content = d.content || '';
        document.getElementById('namesContent').value = content;
        document.getElementById('namesCurrentFile').textContent = name;
        document.getElementById('namesFileSize').textContent = content.length + ' bytes';
        updateNamesCount();
        refreshNamesFilesList();
        namesContentDirty = false;
    } catch (e) {
        alert('Error loading file: ' + (e.message || e));
    }
}

document.getElementById('namesContent').addEventListener('input', () => {
    namesContentDirty = true;
    updateNamesCount();
});

async function saveNamesFile() {
    if (!currentNamesFile) { alert('Select a file first'); return; }
    try {
        const content = document.getElementById('namesContent').value;
        const r = await fetchWithAuth(`${API_BASE_URL}/names/files/${encodeURIComponent(currentNamesFile)}/content`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ content })
        });
        const d = await r.json();
        if (r.ok) {
            namesContentDirty = false;
            document.getElementById('namesFileSize').textContent = content.length + ' bytes';
            updateNamesCount();
            refreshNamesFilesList();
            alert('Saved!');
        } else alert(d.error || 'Save failed');
    } catch (e) {
        alert('Error saving: ' + (e.message || e));
    }
}

function showNewFileDialog() {
    document.getElementById('newFileName').value = '';
    document.getElementById('newFileDialog').classList.add('show');
}

function closeNewFileDialog() {
    document.getElementById('newFileDialog').classList.remove('show');
}

async function createNewFile() {
    const name = document.getElementById('newFileName').value.trim();
    if (!name) { alert('Enter file name'); return; }
    if (!/^[a-zA-Z0-9_-]+$/.test(name)) { alert('Use only letters, numbers, - or _'); return; }
    try {
        const r = await fetchWithAuth(`${API_BASE_URL}/names/files`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name })
        });
        const d = await r.json();
        if (r.ok) {
            closeNewFileDialog();
            refreshNamesFilesList();
            selectNamesFile(name);
        } else alert(d.error || 'Failed');
    } catch (e) {
        alert('Error: ' + (e.message || e));
    }
}

function showRenameDialog() {
    if (!currentNamesFile) { alert('Select a file first'); return; }
    document.getElementById('renameFileName').value = currentNamesFile;
    document.getElementById('renameFileDialog').classList.add('show');
}

function closeRenameDialog() {
    document.getElementById('renameFileDialog').classList.remove('show');
}

async function renameFile() {
    const newName = document.getElementById('renameFileName').value.trim();
    if (!newName || !currentNamesFile) return;
    if (!/^[a-zA-Z0-9_-]+$/.test(newName)) { alert('Use only letters, numbers, - or _'); return; }
    try {
        const r = await fetchWithAuth(`${API_BASE_URL}/names/files/${encodeURIComponent(currentNamesFile)}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ newName })
        });
        if (r.ok) {
            closeRenameDialog();
            currentNamesFile = newName;
            refreshNamesFilesList();
            document.getElementById('namesCurrentFile').textContent = newName;
        } else {
            const d = await r.json();
            alert(d.error || 'Rename failed');
        }
    } catch (e) {
        alert('Error: ' + (e.message || e));
    }
}

async function deleteCurrentFile() {
    if (!currentNamesFile) { alert('Select a file first'); return; }
    if (!confirm(`Delete "${currentNamesFile}"?`)) return;
    try {
        const r = await fetchWithAuth(`${API_BASE_URL}/names/files/${encodeURIComponent(currentNamesFile)}`, { method: 'DELETE' });
        if (r.ok) {
            currentNamesFile = null;
            document.getElementById('namesContent').value = '';
            document.getElementById('namesCurrentFile').textContent = '—';
            document.getElementById('namesFileSize').textContent = '0 bytes';
            document.getElementById('namesCount').textContent = '0';
            refreshNamesFilesList();
        } else {
            const d = await r.json();
            alert(d.error || 'Delete failed');
        }
    } catch (e) {
        alert('Error: ' + (e.message || e));
    }
}
