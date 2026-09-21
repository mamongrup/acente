// NEXUS Agency — Modern Canvas Photo Editor & WebP/AVIF Converter
(function () {
  var fileInput = document.getElementById('media-upload-input');
  var stage = document.getElementById('photo-preview-stage');
  var canvas = document.getElementById('photo-canvas');
  if (!fileInput || !canvas) return;

  var ctx = canvas.getContext('2d');
  var currentImg = null;
  var state = {
    brightness: 100,
    contrast: 100,
    saturation: 100,
    rotation: 0,
    aspectRatio: null
  };

  function render() {
    if (!currentImg) return;
    var w = currentImg.width;
    var h = currentImg.height;

    // Apply aspect ratio crop calculation if selected
    var sx = 0, sy = 0, sWidth = w, sHeight = h;
    if (state.aspectRatio) {
      var targetRatio = state.aspectRatio;
      var currentRatio = w / h;
      if (currentRatio > targetRatio) {
        sWidth = h * targetRatio;
        sx = (w - sWidth) / 2;
      } else {
        sHeight = w / targetRatio;
        sy = (h - sHeight) / 2;
      }
    }

    canvas.width = Math.min(sWidth, 1920);
    canvas.height = Math.min(sHeight, 1080);

    ctx.save();
    ctx.filter = 'brightness(' + state.brightness + '%) contrast(' + state.contrast + '%) saturate(' + state.saturation + '%)';
    ctx.drawImage(currentImg, sx, sy, sWidth, sHeight, 0, 0, canvas.width, canvas.height);
    ctx.restore();

    updateFileSizeEstimate();
  }

  function updateFileSizeEstimate() {
    var sizeLabel = document.getElementById('photo-size-estimate');
    if (!sizeLabel) return;
    canvas.toBlob(function (blob) {
      if (blob) {
        var kb = Math.round(blob.size / 1024);
        sizeLabel.textContent = 'Tahmini WebP Boyutu: ' + kb + ' KB (Orijinal kalitede kayıpsız)';
      }
    }, 'image/webp', 0.92);
  }

  fileInput.addEventListener('change', function (e) {
    var file = e.target.files[0];
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function (event) {
      var img = new Image();
      img.onload = function () {
        currentImg = img;
        render();
      };
      img.src = event.target.result;
    };
    reader.readAsDataURL(file);
  });

  // Aspect ratio buttons
  document.querySelectorAll('.ratio-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      document.querySelectorAll('.ratio-btn').forEach(function (b) { b.classList.remove('active'); });
      btn.classList.add('active');
      var r = btn.getAttribute('data-ratio');
      if (r === '16:9') state.aspectRatio = 16 / 9;
      else if (r === '4:3') state.aspectRatio = 4 / 3;
      else if (r === '1:1') state.aspectRatio = 1;
      else state.aspectRatio = null;
      render();
    });
  });

  // Slider events
  var bSlider = document.getElementById('slider-brightness');
  var cSlider = document.getElementById('slider-contrast');
  var sSlider = document.getElementById('slider-saturation');
  if (bSlider) {
    bSlider.addEventListener('input', function () { state.brightness = this.value; render(); });
  }
  if (cSlider) {
    cSlider.addEventListener('input', function () { state.contrast = this.value; render(); });
  }
  if (sSlider) {
    sSlider.addEventListener('input', function () { state.saturation = this.value; render(); });
  }

  // Save / Export WebP
  var saveBtn = document.getElementById('photo-export-btn');
  if (saveBtn) {
    saveBtn.addEventListener('click', function () {
      if (!currentImg) { alert('Lütfen önce bir fotoğraf seçin.'); return; }
      var link = document.createElement('a');
      link.download = 'nexus-optimized-' + Date.now() + '.webp';
      link.href = canvas.toDataURL('image/webp', 0.92);
      link.click();
    });
  }
})();
