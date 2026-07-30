# SIE Base Panel: Direct GEDI Quick Test Support

## Purpose

This change allows the SIE base panel to run in both modes:

1. **Normal runtime after the login panel**
   - Uses the normal Panel Topology dollar parameters: `$Screen`, `$Number`, and `$Node`.
   - Keeps the existing full-screen startup behavior.
   - Keeps the original `ptms_LoadInitPanel()` workflow.

2. **Direct GEDI Quick Test**
   - Runs inside the existing `_QuickTest_` module.
   - Does not open an additional `WinCC_OA_1` module.
   - Does not move the panel to physical monitor 1.
   - Uses logical Panel Topology values only for module naming and PTMS indexing.
   - Loads the SIE navigation, main, and information panels into the embedded modules of the current base panel.
   - Supports opening faceplates and detail panels.

Upstream project:

- https://github.com/winccoa/winccoa-ae-ui-ptframework/tree/main/3.21

---

## Summary of changed files

| File | Change |
|---|---|
| `scripts/libs/classes/GUI/GUIBasePanel.ctl` | Accept an explicit screen number instead of accessing `$Number` inside the class. Show the title bar only in `_QuickTest_`. |
| `scripts/libs/classes/GUI/GUIFaceplate.ctl` | Resolve the screen number directly from `_QuickTest_` and embedded-module names such as `mainModule_1`. |
| `panels/para/PanelTopology/templates/SIE/basePanel_1024_768_SIE.pnl` | Add separate normal-runtime and Quick Test initialization paths. |
| `scripts/libs/ptms.ctl` | **No changes.** |

---

# 1. Remove the abandoned launcher approach

The final solution must not open the base panel in another module.

Remove any previously added code containing one of the following calls from the SIE base panel:

```ctrl
pt_openBasePanel(...);
ptms_LoadOneBasePanel(...);
ModuleOnWithPanel(...);
ModuleOff(...);
```

Also remove old launcher-related variables and debug text such as:

```ctrl
string sTargetModule = "WinCC_OA_1";
string sQuickTestModule = myModuleName();
```

```text
Opening exact SIE base panel.
Opening SIE base panel through Panel Topology.
```

The base panel must stay inside the module created by GEDI:

```text
_QuickTest_
```

Do not place the base panel inside another panel as a `PANEL_REF`. The base panel must be tested directly.

---

# 2. Modify `GUIBasePanel.ctl`

File:

```text
PT_SIE_FRAMEWORK_3.21/
└─ scripts/
   └─ libs/
      └─ classes/
         └─ GUI/
            └─ GUIBasePanel.ctl
```

## 2.1 Change the constructor signature

### Before

```ctrl
public GUIBasePanel(
  const shape &naviModule,
  const shape &mainModule,
  const shape &headerModule,
  const shape &infoModule,
  const shape &faceplateModule,
  const string &Screen
)
```

### After

```ctrl
public GUIBasePanel(
  const shape &naviModule,
  const shape &mainModule,
  const shape &headerModule,
  const shape &infoModule,
  const shape &faceplateModule,
  const string &Screen,
  const int &screenNumber
)
```

## 2.2 Stop accessing `$Number` inside the class

### Remove

```ctrl
mapping allScreenValues =
  _guiMisc.GetScreenSizeForAllScreens();

mapping screenValues =
  allScreenValues.value((int)$Number);

int screenHeight =
  screenValues.value("H");
```

### Add

```ctrl
mapping allScreenValues =
  _guiMisc.GetScreenSizeForAllScreens();

mapping screenValues =
  allScreenValues.value(screenNumber);

int screenHeight =
  screenValues.value("H");
```

### Reason

A class library cannot rely on `$Number` when the panel is started directly through GEDI Quick Test because that dollar parameter does not exist in `_QuickTest_`.

The base panel now resolves the effective screen number and passes it explicitly to `GUIBasePanel`.

## 2.3 Make the title bar mode-dependent

### Remove

```ctrl
titleBar(FALSE);
```

### Add

```ctrl
titleBar(myModuleName() == "_QuickTest_");
```

Result:

```text
_QuickTest_             -> titleBar(TRUE)
Normal login/fullscreen -> titleBar(FALSE)
```

If the title bar is still hidden because of the frameless window flag, replace the unconditional flag assignment:

```ctrl
self.windowFlags("FramelessWindowHint");
```

with:

```ctrl
if (myModuleName() == "_QuickTest_")
{
  self.windowFlags("Window");
}
else
{
  self.windowFlags("FramelessWindowHint");
}
```

This extra `windowFlags()` change is only required when the platform continues to suppress the title bar despite `titleBar(TRUE)`.

---

# 3. Replace the base-panel `ScopeLib`

Panel:

```text
panels/para/PanelTopology/templates/SIE/basePanel_1024_768_SIE.pnl
```

Location in GEDI:

```text
Panel -> Events -> ScopeLib
```

Replace the complete `ScopeLib` with:

```ctrl
#uses "classes/GUI/GUIBasePanel"
#uses "classes/GUI/GUIFaceplate"

#event faceplateToOpen(
  string sFaceplate,
  bool bOpen = TRUE
)

#event detailToOpen(
  string sPanel,
  dyn_string dsParams,
  bool bOpen = TRUE
)

dyn_string dsPanels;


/*
 * Runtime context used by the SIE base panel.
 */
bool g_bQuickTest = FALSE;
bool g_bQuickTestInitialized = FALSE;

string g_sScreen = "1";
int g_iNumber = 1;
int g_iNode = 0;


/**
 * Resolves the runtime context before GUIBasePanel is created.
 *
 * Normal runtime:
 *   Uses $Screen, $Number and optional $Node.
 *
 * GEDI Quick Test:
 *   Uses logical fallback values without opening a new module.
 */
void InitializePanelContext()
{
  bool bHasPanelTopologyParameters =
    isDollarDefined("$Screen") &&
    isDollarDefined("$Number");

  g_bQuickTest =
    !bHasPanelTopologyParameters;

  if (g_bQuickTest)
  {
    g_sScreen = "1";
    g_iNumber = 1;
    g_iNode = 0;

    return;
  }

  g_sScreen = (string)$Screen;
  g_iNumber = (int)$Number;
  g_iNode = 0;

  if (isDollarDefined("$Node"))
  {
    string sNode = (string)$Node;

    if (sNode != "")
    {
      g_iNode = (int)sNode;
    }
  }
}


/**
 * Creates GUIBasePanel before the object Initialize scripts run.
 */
shared_ptr<GUIBasePanel> CreateBasePanel()
{
  InitializePanelContext();

  return new GUIBasePanel(
    getShape("naviModule"),
    getShape("mainModule"),
    getShape("headerModule"),
    getShape("infoModule"),
    getShape("faceplateModule"),
    g_sScreen,
    g_iNumber
  );
}


/*
 * Keep the original creation timing.
 */
shared_ptr<GUIBasePanel> basePanel =
  CreateBasePanel();
```

## Behavior

### Normal runtime

```ctrl
g_bQuickTest = FALSE;
g_sScreen = (string)$Screen;
g_iNumber = (int)$Number;
g_iNode = the supplied $Node or 0;
```

### Quick Test

```ctrl
g_bQuickTest = TRUE;
g_sScreen = "1";
g_iNumber = 1;
g_iNode = 0;
```

The values `"1"` and `1` are logical PTMS values. They do not determine the physical monitor containing the `_QuickTest_` window.

---

# 4. Replace the base-panel `Initialize` script

Panel:

```text
basePanel_1024_768_SIE.pnl
```

Location in GEDI:

```text
Panel -> Events -> Initialize
```

Replace the complete panel `Initialize` script with:

```ctrl
main()
{
  pt_checkPanelTopologyCache();

  /*
   * Normal startup after the login panel.
   *
   * Keep the original runtime flow unchanged.
   */
  if (!g_bQuickTest)
  {
    moduleMaximize(myModuleName());

    ptms_LoadInitPanel(
      (int)$Number,
      (string)$Screen,
      g_iNode
    );

    basePanel.Initialize();

    return;
  }

  /*
   * Prevent duplicate initialization of one Quick Test instance.
   */
  if (g_bQuickTestInitialized)
  {
    return;
  }

  g_bQuickTestInitialized = TRUE;

  DebugN(
    "BasePanel",
    "Running directly inside _QuickTest_.",
    "Module:",
    myModuleName(),
    "Logical screen:",
    g_sScreen,
    "Logical number:",
    g_iNumber
  );

  /*
   * GEDI Quick Test does not execute the normal login and
   * screen-configuration workflow. Prepare only the minimum
   * PTMS data required by ptms_LoadInitPanel().
   */
  while (dynlen(strptms_Templates) < g_iNumber)
  {
    dynAppend(
      strptms_Templates,
      ""
    );
  }

  while (dynlen(strptms_PanelsToLoad) < g_iNumber)
  {
    dynAppend(
      strptms_PanelsToLoad,
      ""
    );
  }

  strptms_Templates[g_iNumber] =
    "SIE";

  strptms_PanelsToLoad[g_iNumber] =
    "DEFAULTPT";

  tptms_DisplayWidth[g_sScreen] =
    1024;

  tptms_DisplayHeight[g_sScreen] =
    768;

  /*
   * Loads the SIE navi, initial main and information panels into
   * the embedded modules of the current _QuickTest_ base panel.
   */
  ptms_LoadInitPanel(
    g_iNumber,
    g_sScreen,
    g_iNode
  );

  basePanel.Initialize();
}
```

## Important

Do not call `moduleMaximize()` in the Quick Test branch. This keeps the GEDI Quick Test window movable and usable with a title bar.

The normal runtime branch still calls:

```ctrl
moduleMaximize(myModuleName());
```

---

# 5. Keep `mainModule` initialization empty

Object:

```text
mainModule
```

Location:

```text
mainModule -> Events -> Initialize
```

Keep:

```ctrl
main()
{
}
```

No Quick Test code is required there.

---

# 6. Restore the original `infoModule` initialization

Object:

```text
infoModule
```

Remove any Quick Test guard such as:

```ctrl
if (!IsPanelTopologyInstance())
{
  return;
}
```

The `basePanel` object now exists in both modes, so the original information-module code can run in Quick Test and normal runtime.

Use:

```ctrl
main()
{
  string moduleDp =
    basePanel.GetInfoPanelName();

  if (!dpExists(moduleDp))
  {
    dpCreate(
      moduleDp,
      "ExampleDP_Bit"
    );

    delay(1);
  }

  dpSet(
    moduleDp + ".",
    TRUE
  );

  dpConnect(
    "work",
    moduleDp + "."
  );
}


work(
  string dp,
  bool vis
)
{
  this.visible = vis;
}
```

---

# 7. Modify the `faceplateModule` initialization

Object:

```text
faceplateModule
```

Location:

```text
faceplateModule -> Events -> Initialize
```

## 7.1 Remove the old Quick Test guard

Remove:

```ctrl
if (
  !isDollarDefined("$Screen") ||
  !isDollarDefined("$Number")
)
{
  return;
}
```

The faceplate module must initialize in Quick Test too.

## 7.2 Pass the resolved logical screen number

### Before

```ctrl
GUIFaceplate::AddFunctionPtr(
  self.faceplateToOpen,
  self.detailToOpen
);
```

### After

```ctrl
GUIFaceplate::AddFunctionPtr(
  self.faceplateToOpen,
  self.detailToOpen,
  g_iNumber
);
```

Use this complete `main()`:

```ctrl
main()
{
  GUIFaceplate::AddFunctionPtr(
    self.faceplateToOpen,
    self.detailToOpen,
    g_iNumber
  );

  RootPanelOnModule(
    "/IX/faceplates/faceplateSideModuleBasePanel",
    "menu",
    faceplateModule.ModuleName(),
    makeDynString(
      "$moduleName:" + myModuleName(),
      "$modName:" + faceplateModule.ModuleName(),
      "$beamed:" + false
    )
  );

  uiConnect(
    "visibleCB",
    self.faceplateToOpen
  );
}
```

Keep the existing `visibleCB()` function unchanged.

---

# 8. Modify `GUIFaceplate.ctl`

File:

```text
scripts/libs/classes/GUI/GUIFaceplate.ctl
```

The original implementation tries to navigate to a parent module when the current module is `mainModule_1`. In Quick Test, this parent navigation can return an invalid shape.

Replace only the `GetMyScreenNum()` function. Keep the other functions unchanged.

```ctrl
public static int GetMyScreenNum(
  const string module = myModuleName()
)
{
  /*
   * The GEDI Quick Test module has no numeric suffix.
   */
  if (module == "_QuickTest_")
  {
    return 1;
  }

  /*
   * These module names already contain the logical screen number.
   * Do not try to navigate to a parent shape.
   */
  if (
    patternMatch("mainModule_*", module) ||
    patternMatch("naviModule_*", module) ||
    patternMatch("headerModule_*", module) ||
    patternMatch("infoModule_*", module) ||
    patternMatch("faceplateModule_*", module) ||
    patternMatch("detailModule_*", module)
  )
  {
    dyn_string dsModuleParts =
      strsplit(
        module,
        "_"
      );

    int iScreenNumber =
      (int)dsModuleParts.last();

    if (iScreenNumber > 0)
    {
      return iScreenNumber;
    }

    return 1;
  }

  /*
   * Preserve the original fallback behavior for other nested
   * modules and normal WinCC_OA_x modules.
   */
  string tempModule = module;

  if (!patternMatch("WinCC_OA_*", module))
  {
    shape rootPanelShape =
      getShape(
        module + "." +
        rootPanel(module) +
        ":"
      );

    shape modShape =
      rootPanelShape.parentShape();

    shape modPanel =
      modShape.panel();

    tempModule =
      modPanel.moduleName();

    if (
      !patternMatch("mainModule_*", tempModule) &&
      !patternMatch("WinCC_OA_*", tempModule)
    )
    {
      return GetMyScreenNum(
        tempModule
      );
    }
  }

  dyn_string dsSplit =
    strsplit(
      tempModule,
      "_"
    );

  int iScreenNumber =
    (int)dsSplit.last();

  if (iScreenNumber > 0)
  {
    return iScreenNumber;
  }

  return 1;
}
```

## Why both faceplate changes are used

`AddFunctionPtr(..., g_iNumber)` registers the callback at the correct logical screen index.

`GetMyScreenNum()` is still required when a symbol later calls:

```ctrl
GUIFaceplate::TriggerOpenFaceplate(...);
GUIFaceplate::TriggerOpenDetails(...);
```

Those trigger methods resolve the callback index from the current module name, for example:

```text
mainModule_1 -> screen 1
mainModule_2 -> screen 2
```

---

# 9. Keep `detailModule` unchanged

No Quick Test-specific change is required in `detailModule`.

Do not add a guard that prevents it from connecting to `detailToOpen`.

The existing code may remain unchanged.

---

# 10. Do not modify `ptms.ctl`

No production-library modification is required in:

```text
C:/Program Files/Siemens/WinCC_OA/3.21/scripts/libs/ptms.ctl
```

The Quick Test branch only supplies the minimum data expected by the existing implementation:

```ctrl
strptms_Templates[g_iNumber] = "SIE";
strptms_PanelsToLoad[g_iNumber] = "DEFAULTPT";
tptms_DisplayWidth[g_sScreen] = 1024;
tptms_DisplayHeight[g_sScreen] = 768;
```

The normal login workflow continues to initialize these values through the standard Panel Topology screen configuration.

---

# 11. Normal-runtime compatibility

The normal runtime remains isolated from the Quick Test fallback.

Normal runtime executes:

```ctrl
if (!g_bQuickTest)
{
  moduleMaximize(myModuleName());

  ptms_LoadInitPanel(
    (int)$Number,
    (string)$Screen,
    g_iNode
  );

  basePanel.Initialize();

  return;
}
```

Therefore:

- The normal `$Screen` is preserved.
- The normal `$Number` is preserved.
- The normal `$Node` is preserved.
- The user-specific or group-specific screen configuration is preserved.
- The base panel remains full-screen.
- The title bar remains hidden.
- Multi-screen runtime behavior remains controlled by the existing Panel Topology workflow.

---

# 12. Quick Test behavior

When the base panel is opened directly from GEDI without dollar parameters:

```ctrl
g_bQuickTest = TRUE;
g_sScreen = "1";
g_iNumber = 1;
g_iNode = 0;
```

The expected module structure is:

```text
_QuickTest_
├─ headerModule_1
├─ naviModule_1
├─ mainModule_1
├─ infoModule_1
├─ faceplateModule_1
└─ detailModule_1
```

`1` is a logical suffix and PTMS array index. The `_QuickTest_` window remains on the physical monitor where GEDI created it.

No additional module should be opened:

```text
WinCC_OA_1
```

---

# 13. Verification checklist

## Quick Test

1. Open `basePanel_1024_768_SIE.pnl` directly in GEDI.
2. Start Quick Test.
3. Confirm only `_QuickTest_` is opened.
4. Confirm no `WinCC_OA_1` module is created.
5. Confirm the SIE header is loaded.
6. Confirm the SIE navigation panel is loaded.
7. Confirm the initial main topology panel is loaded.
8. Confirm the information module is initialized.
9. Confirm a faceplate can be opened from a symbol in `mainModule_1`.
10. Confirm a detail panel can be opened.
11. Confirm the Quick Test window has a title bar.
12. Confirm the Quick Test window is not forced to full-screen.

Expected debug output:

```text
["BasePanel"]
["Running directly inside _QuickTest_."]
["Module:"]
["_QuickTest_"]
["Logical screen:"]
["1"]
["Logical number:"]
[1]
```

## Normal login

1. Start the UI through the normal login panel.
2. Confirm the correct Panel Topology screen configuration is selected.
3. Confirm the SIE base panel opens full-screen.
4. Confirm the title bar is hidden.
5. Test navigation.
6. Open a faceplate on screen 1.
7. When available, open a faceplate on screen 2.
8. Test detail panels.
9. Confirm no Quick Test debug message is written.

---

# 14. Common errors and their meaning

## `Cannot find dollar parameter $Number`

Cause:

```ctrl
GUIBasePanel.ctl
```

still accesses `$Number` directly.

Fix:

Pass `g_iNumber` to the constructor and use the constructor argument inside the class.

## `Too many arguments for function call GUIBasePanel`

Cause:

The base panel calls the new seven-argument constructor, but the loaded `GUIBasePanel.ctl` still contains the old six-argument signature.

Fix:

Update the exact class file shown in the log and restart `WCCOAui`.

## `modShape == NULL` in `GUIFaceplate::GetMyScreenNum()`

Cause:

The original function tries to navigate from `mainModule_1` to a parent module inside Quick Test.

Fix:

Return the numeric suffix directly for `mainModule_*` and the other embedded-module names.

## `Index out of range: strptms_Templates[num]`

Cause:

The Quick Test branch did not prepare the minimum PTMS screen context.

Fix:

Initialize `strptms_Templates[g_iNumber]` before calling `ptms_LoadInitPanel()`.

## `Index out of range: strptms_PanelsToLoad[num]`

Cause:

Only the template array was initialized.

Fix:

Also initialize:

```ctrl
strptms_PanelsToLoad[g_iNumber] = "DEFAULTPT";
```

## Multiple windows are opened

Cause:

A launcher implementation still calls `ModuleOnWithPanel()`, `ptms_LoadOneBasePanel()` or `pt_openBasePanel()`.

Fix:

Remove the launcher code and call `ptms_LoadInitPanel()` in the current `_QuickTest_` base-panel instance.

---

# 15. Files that must be restarted or reloaded

After changing a class library:

```text
GUIBasePanel.ctl
GUIFaceplate.ctl
```

restart the `WCCOAui` manager. Closing and reopening the Quick Test window alone may leave the previously loaded class definition in memory.

Recommended sequence:

1. Save the `.ctl` files.
2. Save `basePanel_1024_768_SIE.pnl`.
3. Close all Quick Test windows.
4. Restart `WCCOAui`.
5. Reopen GEDI.
6. Test Quick Test.
7. Test normal login runtime.

---

# Final scope

The implementation intentionally changes only the SIE framework files required to support direct Quick Test execution.

It does not change:

- The installed WinCC OA `ptms.ctl` library.
- The Panel Topology data-point structure.
- The login panel workflow.
- The user-specific Panel Topology screen configuration.
- The normal full-screen behavior.
