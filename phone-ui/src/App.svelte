<script>
  import { onDestroy, onMount } from 'svelte';
  import QRCode from 'qrcode';
  import { api, ApiLỗi } from './lib/api.js';
  import ChoicePicker from './lib/ChoicePicker.svelte';
  import { cameraStream, websocketUrl } from './lib/cameraStream.js';
  import CombinedLayoutEditor from './lib/CombinedLayoutEditor.svelte';
  import Xác nhậnDialog from './lib/Xác nhậnDialog.svelte';
  import FlipToggle from './lib/FlipToggle.svelte';
  import HelpButton from './lib/HelpButton.svelte';
  import KhóaIcon from './lib/KhóaIcon.svelte';
  import LazyImage from './lib/LazyImage.svelte';
  import NumberField from './lib/NumberField.svelte';
  import PinchZoomImage from './lib/PinchZoomImage.svelte';
  import SliderControl from './lib/SliderControl.svelte';
  import TextField from './lib/TextField.svelte';
  import ToggleSwitch from './lib/ToggleSwitch.svelte';
  import VideoPlayer from './lib/VideoPlayer.svelte';
  import { formatBytes, videoUrl } from './lib/format.js';

  const cameraIndexes = [1, 2, 3, 4];
  const resolutionOptions = [
    { value: 'economy', label: 'Tiết kiệm · 320×240 mỗi cam · 640×480 ghép' },
    { value: 'standard', label: 'Tiêu chuẩn · 640×480 mỗi cam · 1280×960 ghép' },
    { value: 'high', label: 'Cao · 960×720 mỗi cam · 1920×1440 ghép' },
    { value: 'native', label: 'Gốc · 1280×960 mỗi cam · 2560×1920 ghép' }
  ];
  const settingHelp = {
    volume: 'Chọn ổ lưu trữ để ghi thư mục mới. Bản ghi cũ vẫn ở ổ hiện tại.',
    resolution: 'Điều khiển độ chi tiết và dung lượng từng camera + video ghép. Cao hơn tốn dung lượng nhanh hơn.',
    cameraNames: 'Tên dùng để nhận diện 4 góc camera trên xem trước và trình chỉnh bố cục ghép. Tên file MP4 mới dùng tên tùy chỉnh hợp lệ + thời gian đoạn; tên không hợp lệ sẽ dùng Camera-1 đến Camera-4.',
    cameraOrientation: 'Lật ngang, dọc hoặc cả hai hướng camera. Hướng đã lưu áp dụng cho xem trước trực tiếp và bản ghi mới (riêng + ghép). Bản ghi cũ không đổi.',
    cameraCrop: 'Cắt cùng tỷ lệ từ mọi cạnh cả 4 camera, rồi phóng phần giữa còn lại cho đầy khung. Giảm mép méo mắt cá. Áp dụng cho xem trước và bản ghi mới.',
    combinedLayout: 'Chọn camera ở mỗi góc của video ghép 2×2 mới. Video từng camera riêng không bị đổi thứ tự.',
    quota: 'Dung lượng tối đa máy ghi dùng trên ổ đã chọn. Dọn tự động chỉ xóa bản ghi chưa khóa thuộc máy ghi.',
    retention: 'Bản ghi chưa khóa cũ hơn số ngày này có thể bị dọn tự động. Bản ghi đã khóa luôn được bảo vệ.',
    segment: 'Độ dài mỗi thư mục ghi trước khi bắt đầu đoạn mới. Đoạn ngắn dễ tìm nhưng tạo nhiều file hơn.',
    reserve: 'Ghi hình dừng trước khi dung lượng trống thấp hơn tỷ lệ này, bảo vệ hệ thống xe và app khác khỏi đầy đĩa.',
    date: 'Thay đổi cách hiện ngày ghi. Tên thư mục vẫn giữ định dạng an toàn hệ thống file.'
  };
  let authenticated = null;
  let checkingAuthentication = false;
  let state = null;
  let error = '';
  let busy = false;
  let bulkAction = null;
  let backgroundAccessXác nhận = false;
  let confirmKhóa = null;
  let pin = '';
  let retrySeconds = 0;
  let settingsOpen = false;
  let selectedCamera = null;
  let selectedĐoạn ghi = null;
  let selectedFileName = '';
  let selectedRecordingIds = [];
  let selectionMode = false;
  let longPressState = null;
  let suppressTiếpRecordingClick = false;
  let stateRevision = 0;
  let settingsDraft = {};
  let settingsDirty = false;
  let stateLàm mớiInFlight = false;
  let statusLàm mớiInFlight = false;
  let fisheyePreviewScale = 1;
  let liveCameraIndexes = cameraIndexes;
  let đang hoàn tấtProgress = {};
  let finalizeSocket = null;
  let qrCanvas;
  let recordingListElement;
  let recordingWindowStart = 0;
  let recordingWindowEnd = 12;
  let recordingTopSpacer = 0;
  let recordingBottomSpacer = 0;
  let recordingAverageHeight = 190;
  let recordingWindowFrame = 0;
  const recordingRowHeights = new Map();
  const recordingWindowBuffer = 4;
  const qrValue = new URLSearchParams(window.location.search).get('qr');
  const developmentPin = import.meta.env.DEV
    ? import.meta.env.VITE_MOCK_PIN
    : '';

  $: document.body.classList.toggle(
    'modal-open',
    Boolean(settingsOpen || selectedCamera || selectedĐoạn ghi || confirmKhóa || bulkAction || backgroundAccessXác nhận)
  );
  $: settingsDirty = settingsOpen && state
    ? comparableCài đặt(settingsDraft) !== comparableCài đặt(state.settings)
    : false;
  $: selectionMode = selectedRecordingIds.length > 0;
  $: liveCameraIndexes = orderedCameraIndexes(state?.settings);
  $: syncFinalizeSocket(Boolean(authenticated && state?.segments?.some((segment) => segment.đang hoàn tất)));
  $: fisheyePreviewScale =
    1 /
    Math.max(
      0.3,
      1 - 2 * (Number(settingsDraft.fisheyeCropPercent) || 0) / 100
    );
  $: if (recordingListElement && state?.segments) {
    state.segments.length;
    queueRecordingWindowUpdate();
  }

  onDestroy(() => {
    document.body.classList.remove('modal-open');
    clearRecordingLongPress();
    window.cancelAnimationFrame(recordingWindowFrame);
    syncFinalizeSocket(false);
  });

  function recordingRowHeight(segment) {
    return recordingRowHeights.get(segment.id) || recordingAverageHeight;
  }

  function recordingHeightBetween(segments, start, end) {
    return segments
      .slice(start, end)
      .reduce((total, segment) => total + recordingRowHeight(segment), 0);
  }

  function queueRecordingWindowUpdate() {
    window.cancelAnimationFrame(recordingWindowFrame);
    recordingWindowFrame = window.requestAnimationFrame(updateRecordingWindow);
  }

  function updateRecordingWindow() {
    recordingWindowFrame = 0;
    const segments = state?.segments || [];
    if (!recordingListElement || segments.length === 0) {
      recordingWindowStart = 0;
      recordingWindowEnd = segments.length;
      recordingTopSpacer = 0;
      recordingBottomSpacer = 0;
      return;
    }
    const listTop =
      window.scrollY + recordingListElement.getBoundingClientRect().top;
    const viewportStart = Math.max(0, window.scrollY - listTop);
    const viewportEnd = viewportStart + window.innerHeight;
    let runningHeight = 0;
    let firstVisible = 0;
    while (
      firstVisible < segments.length &&
      runningHeight + recordingRowHeight(segments[firstVisible]) < viewportStart
    ) {
      runningHeight += recordingRowHeight(segments[firstVisible]);
      firstVisible += 1;
    }
    const start = Math.max(0, firstVisible - recordingWindowBuffer);
    let end = firstVisible;
    let coveredHeight = runningHeight;
    while (end < segments.length && coveredHeight < viewportEnd) {
      coveredHeight += recordingRowHeight(segments[end]);
      end += 1;
    }
    end = Math.phút(segments.length, end + recordingWindowBuffer);
    recordingWindowStart = start;
    recordingWindowEnd = end;
    recordingTopSpacer = recordingHeightBetween(segments, 0, start);
    recordingBottomSpacer = recordingHeightBetween(segments, end, segments.length);
    window.requestAnimationFrame(measureVisibleRecordingRows);
  }

  function measureVisibleRecordingRows() {
    if (!recordingListElement) {
      return;
    }
    const measuredRows = Array.from(
      recordingListElement.querySelectorAll('[data-recording-id]')
    );
    let changed = false;
    measuredRows.forEach((row) => {
      const measuredHeight = row.getBoundingClientRect().height + 10;
      const previousHeight = recordingRowHeights.get(row.dataset.recordingId);
      if (!previousHeight || Math.abs(previousHeight - measuredHeight) > 1) {
        recordingRowHeights.set(row.dataset.recordingId, measuredHeight);
        changed = true;
      }
    });
    if (!changed || recordingRowHeights.size === 0) {
      return;
    }
    recordingAverageHeight =
      Array.from(recordingRowHeights.values()).reduce(
        (total, height) => total + height,
        0
      ) / recordingRowHeights.size;
    queueRecordingWindowUpdate();
  }

  function handleRequestLỗi(requestLỗi) {
    if (requestLỗi instanceof ApiLỗi && requestLỗi.status === 401) {
      authenticated = false;
      state = null;
      selectedĐoạn ghi = null;
      settingsOpen = false;
      error = 'Nhập PIN hiện tại hiển thị trên màn hình xe.';
      retrySeconds = Math.max(retrySeconds, requestLỗi.retryAfterSeconds);
      return;
    }
    if (requestLỗi instanceof ApiLỗi && requestLỗi.status === 429) {
      retrySeconds = Math.max(1, requestLỗi.retryAfterSeconds);
    }
    error = requestLỗi.message;
  }

  async function checkAuthentication() {
    if (checkingAuthentication) {
      return;
    }
    checkingAuthentication = true;
    try {
      const result = await api.getAuthentication();
      authenticated = result.authenticated;
      if (authenticated) {
        await refresh();
      }
    } catch (requestLỗi) {
      if (requestLỗi instanceof ApiLỗi && requestLỗi.status === 401) {
        authenticated = false;
        handleRequestLỗi(requestLỗi);
      } else {
        authenticated = null;
        error = 'Kết nối máy ghi bị ngắt. Đang thử lại tự động.';
      }
    } finally {
      checkingAuthentication = false;
    }
  }

  async function authenticate() {
    if (!/^\d{6}$/.test(pin) || retrySeconds > 0) {
      return;
    }
    busy = true;
    try {
      await api.authenticate(pin);
      authenticated = true;
      pin = '';
      error = '';
      await refresh();
    } catch (requestLỗi) {
      if (requestLỗi instanceof ApiLỗi && requestLỗi.status === 401) {
        retrySeconds = Math.max(5, requestLỗi.retryAfterSeconds);
        error = 'PIN sai. Thử lại khi bộ đếm về 0.';
      } else {
        handleRequestLỗi(requestLỗi);
      }
    } finally {
      busy = false;
    }
  }

  async function refresh() {
    if (!authenticated || busy || stateLàm mớiInFlight) {
      return;
    }
    const requestRevision = stateRevision;
    stateLàm mớiInFlight = true;
    try {
      const refreshedState = await api.getState();
      if (requestRevision !== stateRevision) {
        return;
      }
      state = refreshedState;
      selectedRecordingIds = selectedRecordingIds.filter((id) =>
        state.segments.some((segment) => segment.id === id && !segment.active)
      );
      error = '';
      if (selectedĐoạn ghi) {
        selectedĐoạn ghi =
          state.segments.find((segment) => segment.id === selectedĐoạn ghi.id) || null;
        if (
          selectedĐoạn ghi &&
          !selectedĐoạn ghi.files.some((file) => file.name === selectedFileName)
        ) {
          selectedFileName = preferredFile(selectedĐoạn ghi)?.name || '';
        }
      }
    } catch (requestLỗi) {
      if (requestRevision === stateRevision) {
        handleRequestLỗi(requestLỗi);
      }
    } finally {
      stateLàm mớiInFlight = false;
    }
  }

  let lastStateVersion = 0;

  async function refreshStatus() {
    if (!authenticated || !state || statusLàm mớiInFlight) {
      return;
    }
    statusLàm mớiInFlight = true;
    try {
      const status = await api.getStatus();
      const version = Number(status.stateVersion) || 0;
      delete status.stateVersion;
      state = { ...state, ...status };
      error = '';
      // The head unit bumps stateVersion on every recording, finalization,
      // lock, delete, or settings change; refreshing on the cheap 1-giâyond
      // status poll keeps the app current within about a giâyond instead of
      // waiting for the slow full-state timer.
      if (version !== lastStateVersion) {
        lastStateVersion = version;
        refresh();
      }
    } catch (requestLỗi) {
      handleRequestLỗi(requestLỗi);
    } finally {
      statusLàm mớiInFlight = false;
    }
  }

  async function setRecording(enabled) {
    beginStateMutation();
    try {
      state = await api.setRecording(enabled);
      error = '';
    } catch (requestLỗi) {
      handleRequestLỗi(requestLỗi);
    } finally {
      busy = false;
    }
  }

  function openCài đặt() {
    settingsDraft = { ...state.settings };
    settingsOpen = true;
  }

  function updateCài đặtDraft(key, value) {
    settingsDraft = { ...settingsDraft, [key]: value };
  }

  function beginStateMutation() {
    stateRevision += 1;
    busy = true;
  }

  function comparableCài đặt(value) {
    return JSON.stringify(
      Object.keys(state?.settings || {})
        .sort()
        .map((key) => [key, value?.[key]])
    );
  }

  function preferredFile(segment) {
    return (
      segment.files.find((file) => file.name.toLowerCase().includes('combined')) ||
      segment.files[0] ||
      null
    );
  }

  function cameraName(camera) {
    return state?.settings?.[`camera${camera}Name`] || `Camera ${camera}`;
  }

  // The head unit pushes stitch percentages over a small WebSocket while any
  // recording is being finalized; polling the heavy state endpoint for this
  // would cost the head unit a full serialization pass per update.
  function syncFinalizeSocket(wanted) {
    if (wanted && !finalizeSocket) {
      const socket = new WebSocket(websocketUrl('./api/đang hoàn tất/stream'));
      finalizeSocket = socket;
      socket.onmessage = (event) => {
        if (finalizeSocket !== socket) {
          return;
        }
        try {
          const payload = JSON.parse(event.data);
          const next = {};
          (payload.đang hoàn tất || []).forEach((entry) => {
            next[entry.id] = entry.percent;
          });
          const hadEntries = Object.keys(đang hoàn tấtProgress).length > 0;
          đang hoàn tấtProgress = next;
          if (hadEntries && Object.keys(next).length === 0) {
            refresh();
          }
        } catch {
          // Ignore malformed frames; the next push resynchronizes.
        }
      };
      socket.onclose = () => {
        if (finalizeSocket === socket) {
          finalizeSocket = null;
        }
      };
      socket.onerror = () => socket.close();
    } else if (!wanted && finalizeSocket) {
      const socket = finalizeSocket;
      finalizeSocket = null;
      đang hoàn tấtProgress = {};
      socket.onclose = null;
      socket.close();
    }
  }

  function finalizePercent(segment) {
    const pushed = đang hoàn tấtProgress[segment.id];
    if (typeof pushed === 'number') {
      return pushed;
    }
    return typeof segment.đang hoàn tấtPercent === 'number'
      ? segment.đang hoàn tấtPercent
      : -1;
  }

  // Live streams carry unflipped native sensor pixels; the saved camera
  // orientation is applied here as a GPU CSS transform instead of being
  // baked into every JPEG on the head unit.
  function flipTransformStyle(camera, currentCài đặt) {
    if (!currentCài đặt) {
      return '';
    }
    const x = currentCài đặt[`camera${camera}FlipNgang`] ? -1 : 1;
    const y = currentCài đặt[`camera${camera}FlipDọc`] ? -1 : 1;
    return x === 1 && y === 1 ? '' : `transform: scale(${x}, ${y})`;
  }

  function editorPreviewStyle(camera, draft, cropScale) {
    const x = draft[`camera${camera}FlipNgang`] ? -1 : 1;
    const y = draft[`camera${camera}FlipDọc`] ? -1 : 1;
    return `transform: scale(${cropScale * x}, ${cropScale * y})`;
  }

  function orderedCameraIndexes(currentCài đặt) {
    if (!currentCài đặt) {
      return cameraIndexes;
    }
    const order = [
      currentCài đặt.combinedTopLeft,
      currentCài đặt.combinedTopRight,
      currentCài đặt.combinedBottomLeft,
      currentCài đặt.combinedBottomRight
    ].map((cameraIndex) => Number(cameraIndex) + 1);
    return order.length === cameraIndexes.length &&
      new Set(order).size === cameraIndexes.length &&
      order.every((camera) => cameraIndexes.includes(camera))
      ? order
      : cameraIndexes;
  }

  function recordingPreviewUrl(segment) {
    return `./api/segments/${encodeURIComponent(segment.id)}/preview.jpg`;
  }

  function draftCameraNames() {
    return cameraIndexes.map(
      (camera) => settingsDraft[`camera${camera}Name`] || `Camera ${camera}`
    );
  }

  function draftCombinedLayout() {
    return [
      settingsDraft.combinedTopLeft,
      settingsDraft.combinedTopRight,
      settingsDraft.combinedBottomLeft,
      settingsDraft.combinedBottomRight
    ];
  }

  function updateCombinedLayout(layout) {
    settingsDraft = {
      ...settingsDraft,
      combinedTopLeft: layout[0],
      combinedTopRight: layout[1],
      combinedBottomLeft: layout[2],
      combinedBottomRight: layout[3]
    };
  }

  function updateCameraFlip(camera, direction, checked) {
    settingsDraft = {
      ...settingsDraft,
      [`camera${camera}Flip${direction}`]: checked
    };
  }

  function openĐoạn ghi(segment) {
    selectedĐoạn ghi = segment;
    selectedFileName = preferredFile(segment)?.name || '';
  }

  function isRecordingSelected(segment) {
    return selectedRecordingIds.includes(segment.id);
  }

  function toggleRecordingSelection(segment) {
    if (segment.active) {
      return;
    }
    selectedRecordingIds = isRecordingSelected(segment)
      ? selectedRecordingIds.filter((id) => id !== segment.id)
      : [...selectedRecordingIds, segment.id];
  }

  function beginRecordingLongPress(event, segment) {
    if (segment.active || selectionMode) {
      return;
    }
    clearRecordingLongPress();
    longPressState = {
      id: segment.id,
      startX: event.clientX,
      startY: event.clientY,
      timer: window.setTimeout(() => {
        suppressTiếpRecordingClick = true;
        toggleRecordingSelection(segment);
        longPressState = null;
        window.setTimeout(() => {
          suppressTiếpRecordingClick = false;
        }, 350);
      }, 520)
    };
  }

  function moveRecordingLongPress(event) {
    if (
      longPressState &&
      (Math.abs(event.clientX - longPressState.startX) > 12 ||
        Math.abs(event.clientY - longPressState.startY) > 12)
    ) {
      clearRecordingLongPress();
    }
  }

  function clearRecordingLongPress() {
    if (longPressState?.timer) {
      window.clearTimeout(longPressState.timer);
    }
    longPressState = null;
  }

  function handleRecordingClick(segment) {
    clearRecordingLongPress();
    if (suppressTiếpRecordingClick) {
      suppressTiếpRecordingClick = false;
      return;
    }
    if (selectionMode) {
      toggleRecordingSelection(segment);
    } else {
      openĐoạn ghi(segment);
    }
  }

  function requestBulkAction(type) {
    const actionCopy = {
      selectAll: {
        title: 'Chọn tất cả bản ghi?',
        message: 'Mọi bản ghi không đang chạy đang hiện sẽ được chọn.',
        confirmLabel: 'Chọn tất cả'
      },
      clear: {
        title: 'Bỏ chọn?',
        message: 'Không có bản ghi nào bị thay đổi.',
        confirmLabel: 'Bỏ chọn'
      },
      lock: {
        title: 'Khóa các bản ghi đã chọn?',
        message: 'Bản ghi bị khóa được bảo vệ khỏi dọn tự động.',
        confirmLabel: 'Khóa'
      },
      unlock: {
        title: 'Mở khóa các bản ghi đã chọn?',
        message: 'Mở khóaed recordings can be removed by automatic cleanup.',
        confirmLabel: 'Mở khóa'
      }
    };
    bulkAction = { type, ...actionCopy[type] };
  }

  async function setSelectedBản ghiĐã khóa(ids, đã khóa) {
    if (ids.length === 0) {
      return;
    }
    state = await api.setĐã khóa(ids[0], đã khóa);
    await setSelectedBản ghiĐã khóa(ids.slice(1), đã khóa);
  }

  async function performBulkAction() {
    const action = bulkAction;
    bulkAction = null;
    if (!action) {
      return;
    }
    if (action.type === 'selectAll') {
      selectedRecordingIds = state.segments
        .filter((segment) => !segment.active)
        .map((segment) => segment.id);
      return;
    }
    if (action.type === 'clear') {
      selectedRecordingIds = [];
      return;
    }
    beginStateMutation();
    try {
      await setSelectedBản ghiĐã khóa(
        [...selectedRecordingIds],
        action.type === 'lock'
      );
      selectedRecordingIds = [];
      error = '';
    } catch (requestLỗi) {
      handleRequestLỗi(requestLỗi);
    } finally {
      busy = false;
    }
  }

  function closeĐoạn ghi() {
    selectedĐoạn ghi = null;
    selectedFileName = '';
  }

  async function saveCài đặt() {
    beginStateMutation();
    try {
      state = await api.saveCài đặt(settingsDraft);
      settingsOpen = false;
      error = '';
    } catch (requestLỗi) {
      handleRequestLỗi(requestLỗi);
    } finally {
      busy = false;
    }
  }

  async function toggleKhóa(segment) {
    const đã khóa = !segment.đã khóa;
    beginStateMutation();
    try {
      state = await api.setĐã khóa(segment.id, đã khóa);
      selectedĐoạn ghi =
        state.segments.find((candidate) => candidate.id === segment.id) || null;
      error = '';
    } catch (requestLỗi) {
      handleRequestLỗi(requestLỗi);
    } finally {
      busy = false;
      confirmKhóa = null;
    }
  }

  async function requestQuay lạigroundAccess() {
    busy = true;
    try {
      state = await api.requestQuay lạigroundAccess();
      backgroundAccessXác nhận = false;
      error = '';
    } catch (requestLỗi) {
      handleRequestLỗi(requestLỗi);
    } finally {
      busy = false;
    }
  }

  onMount(() => {
    if (qrValue && qrCanvas) {
      QRCode.toCanvas(qrCanvas, qrValue, {
        errorCorrectionLevel: 'M',
        margin: 2,
        width: 260,
        color: { dark: '#08111f', light: '#ffffff' }
      });
      return undefined;
    }
    checkAuthentication();
    const statusTimer = window.setInterval(() => {
      if (retrySeconds > 0) {
        retrySeconds -= 1;
      }
      if (authenticated === null) {
        checkAuthentication();
      } else {
        refreshStatus();
      }
    }, 1000);
    const stateTimer = window.setInterval(refresh, 10000);
    window.addEventListener('scroll', queueRecordingWindowUpdate, { passive: true });
    window.addEventListener('resize', queueRecordingWindowUpdate);
    return () => {
      window.clearInterval(stateTimer);
      window.clearInterval(statusTimer);
      window.removeEventListener('scroll', queueRecordingWindowUpdate);
      window.removeEventListener('resize', queueRecordingWindowUpdate);
    };
  });
</script>

{#if qrValue}
  <main class="qr-only" aria-label="Phone access QR code">
    <canvas bind:this={qrCanvas}></canvas>
  </main>
{:else if authenticated === null}
  <main class="access-shell">
    <giâytion class="panel access-card loading">
      <p class="eyebrow">BYD Camera</p>
      <h1>Đang kiểm tra truy cập điện thoại</h1>
      <p>Kết nốiing giâyurely to the recorder on this network.</p>
    </giâytion>
  </main>
{:else if !authenticated}
  <main class="access-shell">
    <giâytion class="panel access-card">
      <div class="access-mark" aria-hidden="true">
        <svg viewBox="0 0 24 24"><rect x="6" y="2.5" width="12" height="19" rx="3"/><path d="M9.5 6.5h5M11 18h2"/></svg>
      </div>
      <p class="eyebrow">Private local access</p>
      <h1>Nhập PIN trên xe</h1>
      <p>Use the six-digit PIN shown in Truy cập app điện thoại on the car display.</p>
      {#if developmentPin}
        <div class="development-pin">
          Local development PIN <strong>{developmentPin}</strong>
        </div>
      {/if}
      <form class="pin-form" onsubmit={(event) => { event.preventDefault(); authenticate(); }}>
        <input
          type="password"
          inputmode="numeric"
          autocomplete="one-time-code"
          maxlength="6"
          pattern="[0-9][0-9][0-9][0-9][0-9][0-9]"
          aria-label="Six digit phone PIN"
          placeholder="000000"
          value={pin}
          oninput={(event) => (pin = event.currentTarget.value.replace(/\D/g, '').slice(0, 6))}
        />
        <button
          type="submit"
          class="primary-action"
          disabled={busy || pin.length !== 6 || retrySeconds > 0}
        >
          {retrySeconds > 0 ? `Thử lại sau ${retrySeconds}s` : busy ? 'Checking PIN' : 'Open recorder'}
        </button>
      </form>
      {#if error}<div class="error" role="alert">{error}</div>{/if}
    </giâytion>
  </main>
{:else}
  <header class="topbar">
    <div>
      <p class="eyebrow">BYD Camera</p>
      <h1>{state?.recording ? 'Recording' : 'Ready'}</h1>
    </div>
    <button class="icon-button" aria-label="Open settings" onclick={openCài đặt}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2Zm8.2 4.8v-2.4l-2.1-.7a7 7 0 0 0-.7-1.7l1-2-1.7-1.7-2 1a7 7 0 0 0-1.7-.7L12.3 2H9.9l-.7 2.1a7 7 0 0 0-1.7.7l-2-1-1.7 1.7 1 2a7 7 0 0 0-.7 1.7l-2.1.7v2.4l2.1.7c.2.6.4 1.2.7 1.7l-1 2 1.7 1.7 2-1c.5.3 1.1.5 1.7.7l.7 2.1h2.4l.7-2.1c.6-.2 1.2-.4 1.7-.7l2 1 1.7-1.7-1-2c.3-.5.5-1.1.7-1.7l2.1-.7Z"/></svg>
    </button>
  </header>

  <main class="app-shell">
    {#if error}<div class="error" role="alert">{error}</div>{/if}
    {#if !state}
      <giâytion class="main-skeleton" aria-label="Đang tải máy ghi">
        <div class="panel skeleton-recording">
          <span class="skeleton-block skeleton-toggle"></span>
          <span class="skeleton-copy">
            <i></i>
            <i></i>
          </span>
        </div>
        <div class="skeleton-heading"><i></i><i></i></div>
        <div class="panel skeleton-camera-grid">
          <i></i><i></i><i></i><i></i>
        </div>
        <div class="panel skeleton-storage">
          <i></i><i></i><i></i>
        </div>
        <div class="skeleton-heading"><i></i><i></i></div>
        <div class="skeleton-recordings">
          <div class="panel"><i></i><i></i><b></b></div>
          <div class="panel"><i></i><i></i><b></b></div>
        </div>
      </giâytion>
    {:else}
      <giâytion class:recording={state.recording} class="recording-card panel">
        <ToggleSwitch
          checked={state.recording}
          disabled={busy}
          label={state.recording ? 'Pause recording' : 'Start recording'}
          tone="recording"
          onchange={setRecording}
        />
        <div class="recording-copy">
          <strong class="recording-label">
            <span class="status-dot"></span>
            {state.recording ? 'Recording is on' : 'Recording is off'}
          </strong>
          <p>{state.message}</p>
        </div>
      </giâytion>

      <giâytion>
        <div class="giâytion-heading"><h2>Camera trực tiếp</h2><span>Updates automatically</span></div>
        {#if state.wifiName}
          <p class="network-state">
            <strong>{state.wifiName}</strong>
          </p>
        {/if}
        <div class="camera-grid">
          {#each liveCameraIndexes as camera}
            <button
              type="button"
              class="panel camera"
              aria-label={`Open ${cameraName(camera)} live preview`}
              onclick={() => (selectedCamera = camera)}
            >
              <img
                src={`./api/cameras/${camera}.jpg`}
                alt={`${cameraName(camera)} live preview`}
                style={flipTransformStyle(camera, state.settings)}
                use:cameraStream={{
                  path: `./api/cameras/${camera}/stream`,
                  enabled: !settingsOpen && !selectedCamera && !selectedĐoạn ghi
                }}
              />
              <span class="camera-caption">{cameraName(camera)}</span>
            </button>
          {/each}
        </div>
      </giâytion>

      <giâytion class="panel storage">
        <div><span>Còn trống</span><strong>{formatBytes(state.storage.availableBytes)}</strong></div>
        <div><span>Máy ghi</span><strong>{formatBytes(state.storage.recorderBytes)}</strong></div>
        <div><span>Đã khóa</span><strong>{formatBytes(state.storage.đã khóaBytes)}</strong></div>
      </giâytion>

      <giâytion>
        <div class="giâytion-heading">
          <h2>Bản ghi</h2>
          <span>{state.segments.length} available</span>
        </div>
        {#if selectionMode}
          <div class="bulk-selection-toolbar panel" aria-label="Thao tác bản ghi đã chọn">
            <strong>{selectedRecordingIds.length} selected</strong>
            <div>
              <button class="icon-button" aria-label="Chọn tất cả bản ghi" disabled={busy} onclick={() => requestBulkAction('selectAll')}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="8" y="8" width="12" height="12" rx="2"/><path d="m11 14 2 2 4-5M4 16V6a2 2 0 0 1 2-2h10"/></svg>
              </button>
              <button class="icon-button" aria-label="Bỏ chọn bản ghi" disabled={busy} onclick={() => requestBulkAction('clear')}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="7" y="7" width="13" height="13" rx="2"/><path d="M4 16V6a2 2 0 0 1 2-2h10M10 10l7 7m0-7-7 7"/></svg>
              </button>
              <button class="icon-button bulk-lock" aria-label="Khóa bản ghi đã chọn" disabled={busy} onclick={() => requestBulkAction('lock')}>
                <KhóaIcon đã khóa={true} />
              </button>
              <button class="icon-button" aria-label="Mở khóa selected recordings" disabled={busy} onclick={() => requestBulkAction('unlock')}>
                <KhóaIcon đã khóa={false} />
              </button>
            </div>
          </div>
        {/if}
        <div class="segment-list" bind:this={recordingListElement}>
          {#if recordingTopSpacer > 0}
            <div class="recording-window-spacer" style={`height: ${recordingTopSpacer}px`}></div>
          {/if}
          {#each state.segments.slice(recordingWindowStart, recordingWindowEnd) as segment (segment.id)}
            <article
              class:unavailable={segment.active || segment.chưa hoàn tất}
              class:selected={isRecordingSelected(segment)}
              class="segment panel"
              data-recording-id={segment.id}
            >
              <button
                class="segment-summary"
                aria-pressed={selectionMode ? isRecordingSelected(segment) : undefined}
                oncontextmenu={(event) => event.preventDefault()}
                onpointerdown={(event) => beginRecordingLongPress(event, segment)}
                onpointermove={moveRecordingLongPress}
                onpointerup={clearRecordingLongPress}
                onpointercancel={clearRecordingLongPress}
                onclick={() => handleRecordingClick(segment)}
              >
                <span class="segment-copy">
                  <strong>{segment.displayName}</strong>
                  <small>
                    {segment.active ? 'Đang ghi file' : formatBytes(segment.sizeBytes)} ·
                    {segment.active ? 'đang ghi' : segment.đang hoàn tất ? 'đang hoàn tất' : segment.chưa hoàn tất ? 'chưa hoàn tất' : segment.đã khóa ? 'đã khóa' : 'unđã khóa'}
                  </small>
                  {#if segment.đang hoàn tất}
                    {@const percent = finalizePercent(segment)}
                    <span
                      class="finalize-progress"
                      role="progressbar"
                      aria-label={`Finalizing ${segment.displayName}`}
                      aria-valuephút="0"
                      aria-valuemax="100"
                      aria-valuenow={percent >= 0 ? percent : undefined}
                    >
                      <span class="finalize-progress-track">
                        <span
                          class="finalize-progress-fill"
                          class:indeterphútate={percent < 0}
                          style={percent >= 0 ? `width: ${percent}%` : ''}
                        ></span>
                      </span>
                      <strong>{percent >= 0 ? `${percent}%` : '…'}</strong>
                    </span>
                  {/if}
                  {#if !segment.active && !segment.chưa hoàn tất}
                    <LazyImage
                      className="segment-preview-strip"
                      src={recordingPreviewUrl(segment)}
                      alt={`Four camera previews for ${segment.displayName}`}
                    />
                  {/if}
                </span>
              </button>
              <div class:hidden={selectionMode} class="segment-actions">
                <button
                  class:đã khóa={segment.đã khóa}
                  class="segment-lock"
                  disabled={segment.active || busy}
                  aria-label={segment.đã khóa ? `Mở khóa ${segment.displayName}` : `Khóa ${segment.displayName}`}
                  onclick={() => (confirmKhóa = segment)}
                >
                  <KhóaIcon đã khóa={segment.đã khóa} />
                </button>
                <button
                  class="segment-open"
                  aria-label={`Open ${segment.displayName}`}
                  onclick={() => openĐoạn ghi(segment)}
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 7.5h7l2 2h9v9.5H3V7.5Z"/><path d="M3 11h18"/></svg>
                </button>
              </div>
            </article>
          {/each}
          {#if recordingBottomSpacer > 0}
            <div class="recording-window-spacer" style={`height: ${recordingBottomSpacer}px`}></div>
          {/if}
        </div>
      </giâytion>

    {/if}
  </main>

  {#if selectedCamera}
    <div class="modal-backdrop camera-viewer-backdrop">
      <giâytion class="modal camera-viewer-modal">
        <div class="modal-title">
          <div><p class="eyebrow">Camera trực tiếp</p><h2>{cameraName(selectedCamera)}</h2></div>
          <button class="icon-button" aria-label="Đóng live camera" onclick={() => (selectedCamera = null)}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg>
          </button>
        </div>
        <PinchZoomImage
          alt={`${cameraName(selectedCamera)} live preview`}
          src={`./api/cameras/${selectedCamera}.jpg`}
          streamPath={`./api/cameras/${selectedCamera}/stream`}
          flipStyle={flipTransformStyle(selectedCamera, state.settings)}
        />
      </giâytion>
    </div>
  {/if}

  {#if selectedĐoạn ghi}
    {@const selectedFile = selectedĐoạn ghi.files.find((file) => file.name === selectedFileName) || preferredFile(selectedĐoạn ghi)}
    <div class="modal-backdrop">
      <giâytion class="modal segment-detail viewer-modal">
        <div class="modal-title">
          <div><p class="eyebrow">Recording</p><h2>{selectedĐoạn ghi.displayName}</h2></div>
          <button class="icon-button" aria-label="Đóng recording" onclick={closeĐoạn ghi}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg>
          </button>
        </div>
        {#if selectedĐoạn ghi.active}
          <div class="recording-notice">This recording is still being written. Playback and downloads become available after it is finalized.</div>
        {:else if selectedĐoạn ghi.chưa hoàn tất}
          <div class="recording-notice interrupted">This recording was interrupted before its MP4 files finalized. It can be retained or đã khóa here, but deletion is available only from the car.</div>
        {/if}
        <div class="viewer-actions" aria-label="Thao tác bản ghi">
          <button
            class:đã khóa={selectedĐoạn ghi.đã khóa}
            class="viewer-action viewer-lock"
            disabled={selectedĐoạn ghi.active || busy}
            aria-label={selectedĐoạn ghi.đã khóa ? 'Mở khóa recording' : 'Khóa recording'}
            onclick={() => (confirmKhóa = selectedĐoạn ghi)}
          >
            <KhóaIcon đã khóa={selectedĐoạn ghi.đã khóa} />
          </button>
          {#if selectedFile}
            <a
              class="viewer-action"
              aria-label="Mở bằng trình phát ngoài"
              href={videoUrl(selectedĐoạn ghi.id, selectedFile.name)}
              target="_blank"
              rel="noopener"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 5h5v5M12 12l7-7"/><path d="M19 13v6H5V5h6"/></svg>
            </a>
            <a
              class="viewer-action"
              aria-label="Tải về điện thoại"
              download={selectedFile.name}
              href={videoUrl(selectedĐoạn ghi.id, selectedFile.name, true)}
            >
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12m0 0 4-4m-4 4-4-4M5 19h14"/></svg>
            </a>
          {:else}
            <button class="viewer-action" aria-label="Mở bằng trình phát ngoài unavailable" disabled>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 5h5v5M12 12l7-7"/><path d="M19 13v6H5V5h6"/></svg>
            </button>
            <button class="viewer-action" aria-label="Không tải được" disabled>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12m0 0 4-4m-4 4-4-4M5 19h14"/></svg>
            </button>
          {/if}
        </div>
        {#if selectedĐoạn ghi.files.length > 0}
          <div class="viewer-toolbar">
            <ChoicePicker
              label="Bản ghi camera"
              value={selectedFile?.name || ''}
              options={selectedĐoạn ghi.files.map((file) => ({ value: file.name, label: file.name }))}
              onchange={(value) => (selectedFileName = value)}
            />
          </div>
          {#key selectedFile.name}
            <VideoPlayer label={selectedFile.name} src={videoUrl(selectedĐoạn ghi.id, selectedFile.name)} />
          {/key}
        {:else if !selectedĐoạn ghi.active && !selectedĐoạn ghi.chưa hoàn tất}
          <div class="recording-notice interrupted">Không finalized video files are available for this recording.</div>
        {/if}
      </giâytion>
    </div>
  {/if}

  {#if settingsOpen && state}
    <div class="modal-backdrop">
      <giâytion class="modal settings">
        <div class="modal-title settings-header">
          <div><p class="eyebrow">Phone controls</p><h2>Cài đặt máy ghi</h2></div>
          <div class="settings-header-actions">
            <button
              class="icon-button settings-save"
              aria-label={settingsDirty ? 'Lưu settings changes' : 'Cài đặt are already saved'}
              disabled={busy || !settingsDirty}
              onclick={saveCài đặt}
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M5 3h12l2 2v16H5z"/>
                <path d="M8 3v6h8V3M8 21v-7h8v7"/>
              </svg>
            </button>
            <button class="icon-button" aria-label="Đóng settings" onclick={() => (settingsOpen = false)}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg>
            </button>
          </div>
        </div>
        <p class="settings-note">Phone access itself can only be enabled, disabled, or re-keyed from the car display.</p>
        {#if state.backgroundAccessSupported}
          <div
            class:granted={state.backgroundAccessGranted}
            class="settings-group background-access-setting"
          >
          <div>
            <span class="setting-label"><strong>Truy cập ghi hình nền</strong></span>
            <small>
              {state.backgroundAccessGranted
                ? 'Android đã cho phép'
                : 'Tối ưu pin có thể dừng máy ghi khi giao diện xe đóng'}
            </small>
          </div>
          <button
            class:granted={state.backgroundAccessGranted}
            class="background-access-action"
            aria-label="Mở truy cập ghi hình nền trên màn hình xe"
            onclick={() => (backgroundAccessXác nhận = true)}
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" aria-hidden="true">
              <path d="M12 2.75 19 5.7v5.12c0 4.38-2.77 8.34-7 10.43-4.23-2.09-7-6.05-7-10.43V5.7L12 2.75Z"/>
              <path d="m10 8.6 5.1 3.4-5.1 3.4V8.6Z"/>
            </svg>
          </button>
          </div>
        {/if}
        <label><span class="setting-label"><span>Ổ lưu trữ ghi hình</span><HelpButton title="Ổ lưu trữ ghi hình" text={settingHelp.volume} /></span>
          <ChoicePicker
            label="Ổ lưu trữ ghi hình"
            value={settingsDraft.volumeIndex}
            options={state.volumes.map((volume) => ({ value: volume.index, label: volume.label }))}
            onchange={(value) => updateCài đặtDraft('volumeIndex', value)}
          />
        </label>
        <!-- Độ phân giải selection is temporarily hidden; recording always uses
             the native maximum profile. Restore this block to re-enable. -->
        {#if false}
        <label><span class="setting-label"><span>Độ phân giải video</span><HelpButton title="Độ phân giải video" text={settingHelp.resolution} /></span>
          <ChoicePicker
            label="Độ phân giải video"
            multiline={true}
            value={settingsDraft.resolution}
            options={resolutionOptions}
            onchange={(value) => updateCài đặtDraft('resolution', value)}
          />
        </label>
        {/if}
        <div class="settings-group">
          <span class="setting-label"><strong>Tên camera</strong><HelpButton title="Tên camera" text={settingHelp.cameraNames} /></span>
          {#each cameraIndexes as camera}
            <label>Camera {camera}
              <TextField
                label={`Camera ${camera} name`}
                maxlength={32}
                value={settingsDraft[`camera${camera}Name`]}
                onchange={(value) => updateCài đặtDraft(`camera${camera}Name`, value)}
              />
            </label>
          {/each}
        </div>
        <div class="settings-group camera-orientation-group">
          <span class="setting-label"><strong>Hướng camera</strong><HelpButton title="Hướng camera" text={settingHelp.cameraOrientation} /></span>
          <small>Enable either flip direction for each camera. Existing recordings are unchanged.</small>
          <div class="orientation-list">
            {#each cameraIndexes as camera}
              <div class="orientation-row">
                <strong>{settingsDraft[`camera${camera}Name`] || `Camera ${camera}`}</strong>
                <div class="orientation-controls">
                  <FlipToggle
                    direction="horizontal"
                    label={`Ngang flip for ${settingsDraft[`camera${camera}Name`] || `Camera ${camera}`}`}
                    checked={Boolean(settingsDraft[`camera${camera}FlipNgang`])}
                    onchange={(checked) => updateCameraFlip(camera, 'Ngang', checked)}
                  />
                  <FlipToggle
                    direction="vertical"
                    label={`Dọc flip for ${settingsDraft[`camera${camera}Name`] || `Camera ${camera}`}`}
                    checked={Boolean(settingsDraft[`camera${camera}FlipDọc`])}
                    onchange={(checked) => updateCameraFlip(camera, 'Dọc', checked)}
                  />
                </div>
              </div>
            {/each}
          </div>
        </div>
        <div class="settings-group camera-crop-group">
          <span class="setting-label"><strong>Cắt mép mắt cá</strong><HelpButton title="Cắt mép mắt cá" text={settingHelp.cameraCrop} /></span>
          <small>0% keeps the full lens. The preview updates as one shared crop is applied to all cameras.</small>
          <div class="fisheye-preview-grid">
            {#each liveCameraIndexes as camera}
              <div class="fisheye-preview-tile">
                <img
                  src={`./api/editor-cameras/${camera}.jpg`}
                  use:cameraStream={{
                    path: `./api/editor-cameras/${camera}/stream`,
                    enabled: settingsOpen
                  }}
                  alt={`Fisheye crop preview for ${settingsDraft[`camera${camera}Name`] || `Camera ${camera}`}`}
                  style={editorPreviewStyle(camera, settingsDraft, fisheyePreviewScale)}
                />
                <strong>{settingsDraft[`camera${camera}Name`] || `Camera ${camera}`}</strong>
              </div>
            {/each}
          </div>
          <div class="fisheye-slider-row">
            <SliderControl
              label="Cắt mép mắt cá cho tất cả camera"
              value={settingsDraft.fisheyeCropPercent}
              phútimum={0}
              maximum={35}
              onchange={(value) => updateCài đặtDraft('fisheyeCropPercent', value)}
            />
            <strong>{Number(settingsDraft.fisheyeCropPercent) || 0}%</strong>
          </div>
        </div>
        <div class="settings-group">
          <span class="setting-label"><strong>Bố cục video ghép</strong><HelpButton title="Bố cục video ghép" text={settingHelp.combinedLayout} /></span>
          <small>Kéo ô camera sang góc khác để đổi vị trí.</small>
          <CombinedLayoutEditor
            cameraNames={draftCameraNames()}
            layout={draftCombinedLayout()}
            onchange={updateCombinedLayout}
          />
        </div>
        <label><span class="setting-label"><span>Hạn mức máy ghi (GB)</span><HelpButton title="Hạn mức máy ghi" text={settingHelp.quota} /></span>
          <NumberField label="Hạn mức máy ghi (GB)" phút={0.25} max={1000} step={0.25} unit="GB" value={settingsDraft.quotaGb} onchange={(value) => updateCài đặtDraft('quotaGb', value)} />
        </label>
        <label><span class="setting-label"><span>Thời gian lưu (ngày)</span><HelpButton title="Thời gian lưu" text={settingHelp.retention} /></span>
          <NumberField label="Thời gian lưu in ngày" phút={1} max={3650} unit="ngày" value={settingsDraft.retentionDays} onchange={(value) => updateCài đặtDraft('retentionDays', value)} />
        </label>
        <label><span class="setting-label"><span>Độ dài đoạn ghi (phútutes)</span><HelpButton title="Độ dài đoạn ghi" text={settingHelp.segment} /></span>
          <NumberField label="Độ dài đoạn ghi in phútutes" phút={1} max={10} unit="phút" value={settingsDraft.segmentMinutes} onchange={(value) => updateCài đặtDraft('segmentMinutes', value)} />
        </label>
        <label><span class="setting-label"><span>Dung lượng trống tối thiểu (%)</span><HelpButton title="Dung lượng trống tối thiểu" text={settingHelp.reserve} /></span>
          <NumberField label="Phần trăm dung lượng trống tối thiểu" phút={1} max={25} unit="%" value={settingsDraft.phútFreePercent} onchange={(value) => updateCài đặtDraft('phútFreePercent', value)} />
        </label>
        <label><span class="setting-label"><span>Định dạng hiển thị ngày</span><HelpButton title="Định dạng hiển thị ngày" text={settingHelp.date} /></span>
          <ChoicePicker
            label="Định dạng hiển thị ngày"
            value={settingsDraft.dateFormat}
            options={state.dateFormats.map((format) => ({ value: format.id, label: format.label }))}
            onchange={(value) => updateCài đặtDraft('dateFormat', value)}
          />
        </label>
      </giâytion>
    </div>
  {/if}

  {#if backgroundAccessXác nhận && state?.backgroundAccessSupported}
    <Xác nhậnDialog
      title="Open background recording access?"
      message="The car display will open an explanation and Android's battery-optimization control. Xác nhận the request on the car so recording can continue while its interface is closed. Android force-stop still stops every app."
      confirmLabel="Open on car"
      busy={busy}
      onconfirm={requestQuay lạigroundAccess}
      oncancel={() => (backgroundAccessXác nhận = false)}
    />
  {/if}

  {#if confirmKhóa}
    <Xác nhậnDialog
      title={confirmKhóa.đã khóa ? 'Mở khóa this recording?' : 'Khóa this recording?'}
      message={confirmKhóa.đã khóa
        ? 'Automatic cleanup may remove this recording after it is unđã khóa.'
        : 'Bản ghi bị khóa được bảo vệ khỏi dọn tự động.'}
      confirmLabel={confirmKhóa.đã khóa ? 'Mở khóa' : 'Khóa'}
      oncancel={() => (confirmKhóa = null)}
      onconfirm={() => toggleKhóa(confirmKhóa)}
    />
  {/if}

  {#if bulkAction}
    <Xác nhậnDialog
      title={bulkAction.title}
      message={bulkAction.message}
      confirmLabel={bulkAction.confirmLabel}
      oncancel={() => (bulkAction = null)}
      onconfirm={performBulkAction}
    />
  {/if}
{/if}
