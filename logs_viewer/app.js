// Make sure Firebase is loaded
let db;
let auth;
let currentUser = null;
let logs = [];

// Wait for Firebase to initialize
window.addEventListener('DOMContentLoaded', () => {
    const checkDb = setInterval(() => {
        if (window.db && window.auth) {
            db = window.db;
            auth = window.auth;
            clearInterval(checkDb);
            setupEventListeners();
            wireAuth();
        }
    }, 100);

    setTimeout(() => {
        if (!db) {
            clearInterval(checkDb);
            showError('Firebase not initialized. Please check your Firebase configuration in index.html');
        }
    }, 5000);
});

function setupEventListeners() {
    document.getElementById('refreshBtn').addEventListener('click', loadLogs);
    document.getElementById('filterLevel').addEventListener('change', filterLogs);
    document.getElementById('filterOperation').addEventListener('change', filterLogs);
    document.getElementById('limitInput').addEventListener('change', loadLogs);

    document.getElementById('signInBtn').addEventListener('click', async () => {
        try {
            await window.signInWithPopup(auth, window.googleProvider);
        } catch (e) {
            showError(`Sign-in failed: ${e.message}`);
        }
    });
    document.getElementById('signOutBtn').addEventListener('click', async () => {
        try {
            await window.signOut(auth);
        } catch (e) {
            showError(`Sign-out failed: ${e.message}`);
        }
    });
}

function wireAuth() {
    window.onAuthStateChanged(auth, (user) => {
        currentUser = user;
        const status = document.getElementById('authStatus');
        const signInBtn = document.getElementById('signInBtn');
        const signOutBtn = document.getElementById('signOutBtn');
        if (user) {
            status.textContent = `Signed in as ${user.email}`;
            signInBtn.style.display = 'none';
            signOutBtn.style.display = 'inline-block';
            loadLogs();
        } else {
            status.textContent = 'Not signed in';
            signInBtn.style.display = 'inline-block';
            signOutBtn.style.display = 'none';
            logs = [];
            updateStats();
            document.getElementById('logsContainer').innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">🔒</div>
                    <div class="empty-state-text">Sign in with the developer Google account to view logs.</div>
                </div>`;
            document.getElementById('loading').style.display = 'none';
        }
    });
}

async function loadLogs() {
    const loadingEl = document.getElementById('loading');
    const errorEl = document.getElementById('error');
    const logsContainer = document.getElementById('logsContainer');
    const statsEl = document.getElementById('stats');

    loadingEl.style.display = 'block';
    errorEl.style.display = 'none';
    logsContainer.innerHTML = '';

    try {
        if (!db) {
            throw new Error('Firebase not initialized');
        }
        if (!currentUser) {
            loadingEl.style.display = 'none';
            return; // wireAuth() will call loadLogs() once signed in
        }

        const { collection, query, orderBy, limit, getDocs } = await import('https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js');
        
        const limitValue = parseInt(document.getElementById('limitInput').value) || 50;
        const logsRef = collection(db, 'error_logs');
        
        // Query without orderBy first to avoid index requirement
        // We'll sort manually after fetching
        const q = query(logsRef, limit(limitValue * 2)); // Get more to account for any filtering
        
        const querySnapshot = await getDocs(q);
        logs = [];
        
        querySnapshot.forEach((doc) => {
            const data = doc.data();
            logs.push({
                id: doc.id,
                ...data
            });
        });

        console.log(`Fetched ${logs.length} raw logs from Firestore`);

        // Sort by timestamp manually (handles Firestore Timestamp objects)
        logs.sort((a, b) => {
            let aTime, bTime;
            
            // Handle Firestore Timestamp objects
            if (a.timestamp && typeof a.timestamp.toDate === 'function') {
                aTime = a.timestamp.toDate().getTime();
            } else if (a.timestamp && a.timestamp.seconds) {
                // Firestore Timestamp in serialized form
                aTime = a.timestamp.seconds * 1000 + (a.timestamp.nanoseconds || 0) / 1000000;
            } else if (a.timestamp) {
                aTime = new Date(a.timestamp).getTime();
            } else {
                aTime = 0;
            }
            
            if (b.timestamp && typeof b.timestamp.toDate === 'function') {
                bTime = b.timestamp.toDate().getTime();
            } else if (b.timestamp && b.timestamp.seconds) {
                bTime = b.timestamp.seconds * 1000 + (b.timestamp.nanoseconds || 0) / 1000000;
            } else if (b.timestamp) {
                bTime = new Date(b.timestamp).getTime();
            } else {
                bTime = 0;
            }
            
            return bTime - aTime; // Descending order (newest first)
        });

        // Limit after sorting
        logs = logs.slice(0, limitValue);

        console.log(`Loaded ${logs.length} logs after sorting and limiting`);
        if (logs.length > 0) {
            console.log('Sample log:', {
                id: logs[0].id,
                operation: logs[0].operation,
                level: logs[0].level,
                message: logs[0].message,
                timestamp: logs[0].timestamp
            });
        } else {
            console.warn('⚠️ No logs found! Check:');
            console.warn('  1. Firestore security rules allow read access');
            console.warn('  2. Collection name is "error_logs"');
            console.warn('  3. Documents exist in the collection');
        }
        updateStats();
        displayLogs();
        loadingEl.style.display = 'none';
    } catch (error) {
        loadingEl.style.display = 'none';
        let errorMsg = `Error loading logs: ${error.message}`;
        
        // Provide specific guidance based on error type
        if (error.code === 'permission-denied') {
            errorMsg += '\n\n⚠️ Permission Denied - Check:\n';
            errorMsg += '1. Firestore rules are published\n';
            errorMsg += '2. Rules allow read access to error_logs collection\n';
            errorMsg += '3. Try hard refresh (Ctrl+Shift+R / Cmd+Shift+R)';
        } else if (error.code === 'failed-precondition') {
            errorMsg += '\n\n⚠️ Index Missing - Create index in Firestore Console';
        }
        
        showError(errorMsg);
        console.error('Error loading logs:', error);
        console.error('Error code:', error.code);
        console.error('Error stack:', error.stack);
    }
}

function updateStats() {
    const statsEl = document.getElementById('stats');
    const total = logs.length;
    const errors = logs.filter(l => l.level === 'error').length;
    const warnings = logs.filter(l => l.level === 'warning').length;
    const operations = [...new Set(logs.map(l => l.operation).filter(Boolean))].length;

    statsEl.innerHTML = `
        <div class="stat-item">
            <span class="stat-label">Total Logs</span>
            <span class="stat-value">${total}</span>
        </div>
        <div class="stat-item">
            <span class="stat-label">Errors</span>
            <span class="stat-value" style="color: #f44336">${errors}</span>
        </div>
        <div class="stat-item">
            <span class="stat-label">Warnings</span>
            <span class="stat-value" style="color: #ff9800">${warnings}</span>
        </div>
        <div class="stat-item">
            <span class="stat-label">Operations</span>
            <span class="stat-value">${operations}</span>
        </div>
    `;
}

function filterLogs() {
    displayLogs();
}

function displayLogs() {
    const logsContainer = document.getElementById('logsContainer');
    const levelFilter = document.getElementById('filterLevel').value;
    const operationFilter = document.getElementById('filterOperation').value;

    let filteredLogs = logs;

    if (levelFilter !== 'all') {
        filteredLogs = filteredLogs.filter(l => l.level === levelFilter);
    }

    if (operationFilter !== 'all') {
        filteredLogs = filteredLogs.filter(l => l.operation === operationFilter);
    }

    if (filteredLogs.length === 0) {
        logsContainer.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📭</div>
                <div class="empty-state-text">No logs found matching the filters</div>
            </div>
        `;
        return;
    }

    logsContainer.innerHTML = filteredLogs.map(log => createLogCard(log)).join('');
    
    // Add event listeners to toggle buttons
    document.querySelectorAll('.toggle-stacktrace').forEach(btn => {
        btn.addEventListener('click', function() {
            const stacktraceEl = this.nextElementSibling;
            stacktraceEl.classList.toggle('expanded');
            this.textContent = stacktraceEl.classList.contains('expanded') ? 'Hide Stack Trace' : 'Show Stack Trace';
        });
    });
}

function createLogCard(log) {
    // Handle Firestore Timestamp objects properly
    let timestamp;
    if (log.timestamp && typeof log.timestamp.toDate === 'function') {
        timestamp = log.timestamp.toDate();
    } else if (log.timestamp && log.timestamp.seconds) {
        // Firestore Timestamp in serialized form
        timestamp = new Date(log.timestamp.seconds * 1000 + (log.timestamp.nanoseconds || 0) / 1000000);
    } else if (log.timestamp) {
        timestamp = new Date(log.timestamp);
    } else {
        timestamp = new Date();
    }
    
    const timeStr = timestamp.toLocaleString();
    
    const contextHtml = log.context ? `
        <div class="log-context">
            <div class="log-context-title">Context</div>
            ${Object.entries(log.context).map(([key, value]) => `
                <div class="log-context-item">
                    <span class="log-context-key">${key}:</span>
                    <span class="log-context-value">${formatValue(value)}</span>
                </div>
            `).join('')}
        </div>
    ` : '';

    const stacktraceHtml = log.stackTrace ? `
        <button class="toggle-stacktrace">Show Stack Trace</button>
        <div class="log-stacktrace">${escapeHtml(log.stackTrace)}</div>
    ` : '';

    return `
        <div class="log-card ${log.level}">
            <div class="log-header">
                <div>
                    <span class="log-level ${log.level}">${log.level}</span>
                    ${log.operation ? `<span class="log-operation">${log.operation}</span>` : ''}
                </div>
                <div class="log-timestamp">${timeStr}</div>
            </div>
            <div class="log-message">${escapeHtml(log.message)}</div>
            ${log.error ? `<div class="log-error">${escapeHtml(log.error)}</div>` : ''}
            ${contextHtml}
            ${stacktraceHtml}
            <div class="log-user-info">
                ${log.userEmail ? `<span>User: ${log.userEmail}</span>` : ''}
                ${log.userId ? `<span>ID: ${log.userId}</span>` : ''}
            </div>
            ${log.deviceInfo ? `
                <div class="log-device-info">
                    <span>Platform: ${log.deviceInfo.platform || 'N/A'}</span>
                    <span>Version: ${log.deviceInfo.platformVersion || 'N/A'}</span>
                    ${log.deviceInfo.isDebug !== undefined ? `<span>Debug: ${log.deviceInfo.isDebug}</span>` : ''}
                </div>
            ` : ''}
        </div>
    `;
}

function formatValue(value) {
    if (value === null || value === undefined) return 'N/A';
    if (typeof value === 'object') return JSON.stringify(value);
    if (typeof value === 'string' && value.length > 100) {
        return value.substring(0, 100) + '...';
    }
    return String(value);
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showError(message) {
    const errorEl = document.getElementById('error');
    errorEl.textContent = message;
    errorEl.style.display = 'block';
}
