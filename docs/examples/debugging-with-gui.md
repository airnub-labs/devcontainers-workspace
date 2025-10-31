# Example: Debugging with GUI Desktop

This example demonstrates how to use the browser-based GUI desktop (noVNC or Webtop) for debugging visual applications, running browser automation tests, and troubleshooting UI issues.

> **⚠️ Customization Note:**
> This example uses `$WORKSPACE_ROOT` as the workspace root directory. By default, this is `$WORKSPACE_ROOT`, but you can customize it by setting the `WORKSPACE_ROOT` environment variable. Replace `my-app` with your actual project directory name.

---

## Scenario

You're developing a web application and need to:
- Debug browser-specific rendering issues
- Run Playwright/Selenium tests in a real browser
- Test file uploads/downloads
- Inspect visual regressions
- Debug Chrome DevTools issues

---

## Prerequisites

- Dev Container is running
- GUI provider is configured (noVNC or Webtop)
- Your application is running (e.g., `pnpm dev` on port 3000)

---

## Available GUI Providers

The workspace supports multiple GUI providers:

| Provider | Port | Protocol | Best For |
|----------|------|----------|----------|
| **noVNC** | 6080 | HTTP | Lightweight, simple desktop access |
| **Webtop** | 3001 | HTTPS | Full desktop environment, audio support |
| **Chrome CDP** | 9222 | HTTP | Headless browser debugging |

See [GUI Desktops Guide](../guides/gui-desktops.md) for detailed comparison.

---

## Workflow 1: Access the Desktop

### For noVNC (Default)

#### Step 1: Forward the Port

**In VS Code:**
1. Open **Ports** panel (View → Ports)
2. Find port **6080**
3. Click the globe icon 🌐

**In Codespaces:**
- URL pattern: `https://<workspace>-6080.<region>.app.github.dev`

---

#### Step 2: Open Desktop

The desktop should load automatically in your browser.

**What you'll see:**
- Full Linux desktop (XFCE or similar)
- Terminal window
- File manager
- Web browsers (Chrome, Firefox)

---

#### Step 3: Verify Desktop Works

```bash
# In the desktop's terminal
echo "Hello from GUI desktop!"

# Check display
echo $DISPLAY
# Should output: :1 or similar
```

---

### For Webtop (If Configured)

#### Step 1: Forward the Port

Forward port **3001** (HTTPS)

---

#### Step 2: Login

**Open in browser:** `https://localhost:3001`

**Login with credentials from `.devcontainer/.env`:**
```bash
# Check credentials
cat .devcontainer/.env | grep WEBTOP
```

Expected output:
```
WEBTOP_USER=abc
WEBTOP_PASSWORD=abc
```

Enter credentials when prompted.

---

## Workflow 2: Debug Your Application in Desktop Browser

### Step 1: Open Your App in Desktop

Inside the GUI desktop:

1. **Open Chrome or Firefox**
   - Look in applications menu or desktop icons

2. **Navigate to your app**
   ```
   http://localhost:3000
   ```

   **Note:** Use `localhost`, not the forwarded Codespaces URL

---

### Step 2: Use Browser DevTools

**Open DevTools:**
- Chrome: F12 or Right-click → Inspect
- Firefox: F12 or Right-click → Inspect Element

**Debug as normal:**
- Console logs
- Network requests
- Element inspection
- JavaScript debugging
- Performance profiling

---

### Step 3: Test Features That Need GUI

**File uploads:**
```javascript
// Test file upload
// 1. Create a test file in the desktop
// 2. Use file picker in your app
// 3. Upload the file
// 4. Verify upload in your app logs
```

**File downloads:**
```javascript
// Test file download
// 1. Trigger download in your app
// 2. Check Downloads folder in desktop
// 3. Open and verify file
```

**Clipboard operations:**
```javascript
// Test copy/paste
// 1. Copy text in your app
// 2. Paste into desktop text editor
// 3. Verify clipboard content
```

---

## Workflow 3: Run Playwright Tests

### Step 1: Configure Playwright for GUI Mode

**Edit `playwright.config.ts`:**
```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  // Use headed mode in GUI desktop
  use: {
    headless: false,
    viewport: { width: 1280, height: 720 },
    video: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  // Display server
  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: true,
  },
});
```

---

### Step 2: Run Tests in Desktop

**Open terminal in GUI desktop:**
```bash
cd $WORKSPACE_ROOT/my-app

# Install Playwright browsers (if not already)
pnpm exec playwright install

# Run tests in headed mode
DISPLAY=:1 pnpm exec playwright test
```

**What you'll see:**
- Browser windows opening in the desktop
- Tests executing visually
- Real-time interaction

---

### Step 3: Debug Test Failures

**Run specific test with debug mode:**
```bash
DISPLAY=:1 pnpm exec playwright test --debug
```

**Use Playwright Inspector:**
- Set breakpoints
- Step through test
- Inspect elements
- Record actions

---

## Workflow 4: Debug Browser Automation Issues

### Scenario: Selenium Test Failing

#### Step 1: Configure Selenium

**Install Selenium:**
```bash
cd $WORKSPACE_ROOT/my-app
pnpm add -D selenium-webdriver
```

**Create test script (`test-selenium.js`):**
```javascript
const { Builder, By, until } = require('selenium-webdriver');

(async function example() {
  // Connect to Chrome in GUI desktop
  let driver = await new Builder()
    .forBrowser('chrome')
    .build();

  try {
    // Navigate to app
    await driver.get('http://localhost:3000');

    // Wait for element
    await driver.wait(until.elementLocated(By.css('h1')), 10000);

    // Get text
    let heading = await driver.findElement(By.css('h1'));
    let text = await heading.getText();
    console.log('Page heading:', text);

    // Take screenshot
    await driver.takeScreenshot().then((image) => {
      require('fs').writeFileSync('screenshot.png', image, 'base64');
    });
  } finally {
    await driver.quit();
  }
})();
```

---

#### Step 2: Run in Desktop

**In GUI desktop terminal:**
```bash
cd $WORKSPACE_ROOT/my-app

# Run selenium test
DISPLAY=:1 node test-selenium.js
```

**Watch the browser:**
- Browser opens automatically
- Actions execute visually
- Debug by observing behavior

---

## Workflow 5: Visual Regression Testing

### Step 1: Install Visual Testing Tool

```bash
cd $WORKSPACE_ROOT/my-app

# Option A: Playwright visual testing
pnpm add -D @playwright/test

# Option B: BackstopJS
pnpm add -D backstopjs
```

---

### Step 2: Create Visual Test

**Playwright example (`tests/visual.spec.ts`):**
```typescript
import { test, expect } from '@playwright/test';

test('homepage visual regression', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Take screenshot and compare
  await expect(page).toHaveScreenshot('homepage.png', {
    maxDiffPixels: 100,
  });
});
```

---

### Step 3: Run Visual Tests in Desktop

```bash
# In GUI desktop terminal
cd $WORKSPACE_ROOT/my-app
DISPLAY=:1 pnpm exec playwright test tests/visual.spec.ts
```

**Generate baseline:**
```bash
DISPLAY=:1 pnpm exec playwright test tests/visual.spec.ts --update-snapshots
```

---

### Step 4: Review Differences

**When tests fail:**
```bash
# View diff report
pnpm exec playwright show-report
```

**In the GUI desktop:**
- Open HTML report in browser
- Compare side-by-side diffs
- Decide: bug or intentional change?

---

## Workflow 6: Debug Chrome DevTools Protocol

### Scenario: Connect Chrome DevTools to Your App

#### Step 1: Enable Remote Debugging

**Start Chrome with debugging port:**
```bash
# In GUI desktop terminal
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug
```

---

#### Step 2: Connect from Host VS Code

**Install Chrome DevTools extension:**
1. Command Palette → Extensions: Install Extensions
2. Search "Debugger for Chrome"
3. Install

**Create launch configuration (`.vscode/launch.json`):**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "chrome",
      "request": "attach",
      "name": "Attach to Chrome in Container",
      "port": 9222,
      "url": "http://localhost:3000",
      "webRoot": "${workspaceFolder}/my-app"
    }
  ]
}
```

---

#### Step 3: Debug from VS Code

1. Navigate to your app in desktop Chrome: `http://localhost:3000`
2. In VS Code, press F5 or Run → Start Debugging
3. Set breakpoints in your source code
4. Interact with app in desktop browser
5. Debugger pauses in VS Code

---

## Workflow 7: Inspect Network Issues

### Scenario: API Call Failing, Need to Debug

#### Step 1: Open Desktop Browser

Navigate to your app: `http://localhost:3000`

---

#### Step 2: Open DevTools Network Panel

1. Press F12
2. Go to **Network** tab
3. Refresh page or trigger action

---

#### Step 3: Inspect Failed Requests

**Look for:**
- Red failed requests
- Status codes (400, 500, etc.)
- Request headers
- Response body
- Timing information

**Copy as cURL:**
```bash
# Right-click request → Copy → Copy as cURL
# Paste in terminal to reproduce
curl 'http://localhost:54321/rest/v1/users' \
  -H 'apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
```

---

## Workflow 8: Test Responsive Design

### Step 1: Open Desktop Browser

Navigate to app: `http://localhost:3000`

---

### Step 2: Use Responsive Design Mode

**Chrome:**
- Press Ctrl+Shift+M (Cmd+Shift+M on Mac)
- Select device presets (iPhone, iPad, etc.)
- Or enter custom dimensions

**Firefox:**
- Press Ctrl+Shift+M
- Select device
- Test rotation (portrait/landscape)

---

### Step 3: Test Different Screen Sizes

**Common breakpoints to test:**
```
320px  - Mobile (small)
375px  - Mobile (medium)
768px  - Tablet
1024px - Desktop (small)
1440px - Desktop (large)
```

---

### Step 4: Take Screenshots

**Manually:**
- Chrome: Right-click → Capture screenshot
- Firefox: Screenshot tool in DevTools

**Automated with Playwright:**
```typescript
test('responsive design', async ({ page }) => {
  // Test different viewports
  const sizes = [
    { width: 375, height: 667 },   // iPhone
    { width: 768, height: 1024 },  // iPad
    { width: 1440, height: 900 },  // Desktop
  ];

  for (const size of sizes) {
    await page.setViewportSize(size);
    await page.goto('http://localhost:3000');
    await expect(page).toHaveScreenshot(`homepage-${size.width}x${size.height}.png`);
  }
});
```

---

## Advanced: Record User Session

### Step 1: Install Screen Recorder

**In GUI desktop:**
```bash
# Install recordMyDesktop (if not already installed)
sudo apt-get update
sudo apt-get install -y gtk-recordmydesktop
```

---

### Step 2: Start Recording

1. Open recordMyDesktop application
2. Click **Record**
3. Reproduce the bug in your app
4. Click **Stop** when done

---

### Step 3: Share Recording

```bash
# Find recording file
ls ~/Videos/*.ogv

# Convert to MP4 (optional)
ffmpeg -i ~/Videos/out.ogv ~/Videos/bug-recording.mp4

# Copy to host filesystem
cp ~/Videos/bug-recording.mp4 $WORKSPACE_ROOT/my-app/
```

---

## Troubleshooting

### Desktop Won't Load

**Symptom:** Port 6080 shows "Connection refused"

**Solution:**
```bash
# Check if VNC server is running
ps aux | grep vnc

# If not running, check container logs
docker logs <container-name>

# Restart VNC server (if using noVNC)
vncserver -kill :1
vncserver :1 -geometry 1920x1080 -depth 24
```

---

### Slow Desktop Performance

**Symptom:** Desktop is laggy or unresponsive

**Solutions:**

1. **Lower resolution:**
   ```bash
   # Restart VNC with lower resolution
   vncserver -kill :1
   vncserver :1 -geometry 1280x720 -depth 16
   ```

2. **Disable compositing:**
   - In desktop: Settings → Window Manager Tweaks → Compositor
   - Uncheck "Enable display compositing"

3. **Use headless mode when possible:**
   ```bash
   # Use Chrome headless instead of GUI
   google-chrome --headless --remote-debugging-port=9222
   ```

---

### Browser Not Connecting to App

**Symptom:** `http://localhost:3000` shows "Connection refused" in desktop browser

**Cause:** App not running or wrong port

**Solution:**
```bash
# In VS Code terminal (not desktop terminal)
cd $WORKSPACE_ROOT/my-app
pnpm dev

# Verify port
lsof -i :3000
```

**Or check port in Ports panel and use the forwarded address**

---

### Clipboard Not Working

**Symptom:** Can't copy/paste between host and desktop

**Solution:**

**For noVNC:**
- Use the clipboard panel on the left side
- Copy to/from this panel to transfer text

**For Webtop:**
- Clipboard sharing should work automatically
- Check browser permissions for clipboard access

---

### Display Variable Not Set

**Symptom:**
```
Error: Cannot open display
```

**Solution:**
```bash
# In desktop terminal, set DISPLAY
export DISPLAY=:1

# Or specify when running command
DISPLAY=:1 google-chrome
```

---

## Best Practices

### 1. Use Headless When Possible

```bash
# ✅ Faster for CI/CD
pnpm exec playwright test --headed=false

# ⚠️ Use GUI only for debugging
DISPLAY=:1 pnpm exec playwright test --headed
```

---

### 2. Clean Up After Tests

```bash
# Kill browser processes
pkill chrome
pkill firefox

# Clean temp files
rm -rf /tmp/chrome-*
```

---

### 3. Record Videos for Bug Reports

Always record screen when reproducing bugs:
- Makes bug reports clearer
- Helps team understand issue
- Useful for documentation

---

### 4. Use Screenshots for Visual Tests

```typescript
// Playwright: automatic screenshot on failure
use: {
  screenshot: 'only-on-failure',
}

// Or explicit screenshot
await page.screenshot({ path: 'debug.png', fullPage: true });
```

---

## Related Examples

- [Setting Up a New Project](./setting-up-new-project.md)
- [Switching Between Projects](./switching-projects.md)
- [Running Migrations](./running-migrations.md)

## Related Documentation

- [GUI Desktops Guide](../guides/gui-desktops.md)
- [Ports & Services Reference](../reference/ports-and-services.md)
- [Troubleshooting](../reference/troubleshooting.md)

---

**Last updated:** 2025-10-31
