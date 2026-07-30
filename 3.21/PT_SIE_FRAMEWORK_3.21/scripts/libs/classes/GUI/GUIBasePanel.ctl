// $License: NOLICENSE
//--------------------------------------------------------------------------------
/**
  @file $relPath
  @copyright $copyright
  @author n.holzersoellner
*/
#uses "classes/GUI/GUIMisc"
#uses "classes/GUI/GUIFaceplate"
#uses "classes/GUI/GUINaviPanelButton"
#uses "classes/GUI/GUINaviButton"
#uses "classes/Timer/Timer"
#uses "classes/GUI/GUINaviButtonCollection"
/**
 * @brief Base class for GUI panels, providing common functionality for navigation and panel management.
 */
class GUIBasePanel
{
  private const int Admin = 1; //!< Admin user type
  private const int User = 2; //!< Regular user type
  private const int Customer = 3; //!< Customer user type
  private const int User1 = 4; //!< User type 1
  private const int Admin_2 = 0; //!< Admin user type 2
  private bool _menuOpen = TRUE; //!< Indicates if the navigation menu is open
  private bool _logged = TRUE; //!< Indicates if the user is logged in
  private shared_ptr<Timer> _hideNavi = new Timer(1); //!< Timer for hiding the navigation menu
  private shared_ptr<GUINaviButtonCollection> _naviButtons; //!< Collection of navigation buttons
  private shared_ptr<GUIMisc> _guiMisc; //!< Miscellaneous GUI utilities
  private shape _naviModule; //!< Navigation module shape
  private shape _mainModule; //!< Main module shape
  private shape _infoModule; //!< Information module shape
  private shape _headerModule; //!< Header module shape
  private shape _faceplateModule; //!< Faceplate module shape
  private string _actualPanel; //!< Name of the currently active panel
  private string _mainPanelName; //!< Name of the main panel
  private string _infoPanelName; //!< Name of the information panel
  /**
   * @brief Constructor for GUIBasePanel.
   * @param naviModule The navigation module shape.
   * @param mainModule The main module shape.
   * @param headerModule The header module shape.
   * @param infoModule The information module shape.
   * @param faceplateModule The faceplate module shape.
   * @param Screen The screen identifier for building module names.
   */
  public GUIBasePanel(const shape &naviModule, const shape &mainModule, const shape &headerModule, const shape &infoModule, const shape &faceplateModule, const string &Screen)
  {
    _guiMisc = new GUIMisc();
    _naviModule = naviModule;
    _mainModule = mainModule;
    _infoModule = infoModule;
    _headerModule = headerModule;
    _faceplateModule = faceplateModule;
    naviModule.ModuleName = ptms_BuildModuleName("naviModule", Screen);
    mainModule.ModuleName = ptms_BuildModuleName("mainModule", Screen);
    infoModule.ModuleName = ptms_BuildModuleName("infoModule", Screen);
    headerModule.ModuleName = ptms_BuildModuleName("headerModule", Screen);
    faceplateModule.ModuleName = ptms_BuildModuleName("faceplateModule", Screen);
    RootPanelOnModule("para/PanelTopology/templates/SIE/headerPanel_1024_768_SIE.pnl", "Header", headerModule.ModuleName(), makeDynString());

    dyn_int headerSize = _headerModule.sizeAsDyn();
    dyn_int naviSize = _naviModule.sizeAsDyn();

    mapping allScreenValues = _guiMisc.GetScreenSizeForAllScreens();

    /*
     * Normal runtime:
     *   Use the physical screen number supplied by Panel Topology.
     *
     * GEDI Quick Test:
     *   $Number is not available. Use the numeric Screen value when
     *   possible and otherwise fall back to logical screen 1.
     *
     * Keeping the constructor signature unchanged preserves all
     * existing six-argument calls in the project.
     */
    int iScreenNumber = 1;

    if (isDollarDefined("$Number"))
    {
      iScreenNumber = (int)$Number;
    }
    else
    {
      int iScreenFromName = (int)Screen;

      if (iScreenFromName > 0)
      {
        iScreenNumber = iScreenFromName;
      }
    }

    mapping screenValues = allScreenValues.value(iScreenNumber);
    int screenHeight = screenValues.value("H");

    _naviModule.size(naviSize.at(0), screenHeight - headerSize.at(1));
    self.windowFlags("FramelessWindowHint");
    self.styleSheet(_guiMisc.GetCssString());
    colorSetActiveScheme("Siemens_Dark");
    setActiveIconTheme("Siemens_Dark");

    setScaleStyle(SCALE_FIT_TO_MODULE, _mainModule.ModuleName);
    setScaleStyle(SCALE_NONE, _naviModule.ModuleName);


    _infoPanelName = "Info_" + createUuid();
    nameCheck(_infoPanelName);

    _mainPanelName = "Main_" + createUuid();
    nameCheck(_mainPanelName);
    _actualPanel = _mainPanelName;
    //If title bar is not needed, change this:
    bool bQuickTest = myModuleName() == "_QuickTest_";

titleBar(bQuickTest);
  }

  /**
   * @brief Initializes the GUIBasePanel, setting up navigation buttons and connections.
   */
  public void Initialize()
  {
    assignPtr(_naviButtons, invokeMethod(getShape(_naviModule.ModuleName(), rootPanel(_naviModule.ModuleName()), ""), "GetGuiNaviButtonCollection"));
    classConnect(this, ClickedCB, _naviButtons, GUINaviButtonCollection::ClickedEvent);

    if (_menuOpen)
    {
      ClickedCB(2, "", nullptr);
    }
    if (getPath(PANELS_REL_PATH, "tunnel/tunnelBase.pnl") != "")
    {
      ClickedCB(1, "tunnel/tunnelBase.pnl", _naviButtons.GetByIndex(0));
    }

    dpConnect("HomePanelCB", 0, "_Ui_" + myManNum() + ".UserName");

    classConnect(this, HideNavi, _hideNavi, Timer::TimerDone);
  }

  /**
   * @brief Gets the name of the main panel.
   * @return The name of the main panel.
   */
  public string GetInfoPanelName()
  {
    return _infoPanelName;
  }

  /**
   * @brief Handles click events for navigation buttons in the GUI panel.
   *
   * This callback function processes different click modes for navigation buttons,
   * such as opening main panels, handling special cases (e.g., "tunnel", "gis", "settings"),
   * and toggling the navigation menu's visibility and size. It manages panel transitions,
   * updates button states, and triggers related GUI actions.
   *
   * @param mode The mode of the click event (e.g., open panel, toggle menu).
   * @param value The value associated with the click event, which may contain panel identifiers or parameters.
   * @param button Shared pointer to the GUINaviButton that was clicked.
   */
  private void ClickedCB(const int &mode, const anytype &value, shared_ptr<GUINaviButton> button)
  {
    dyn_int moduleSize;
    dyn_int newModuleSize;
    dyn_string params;
    int moduleHeight;
    anytype _value = value;
    switch (mode)
    {
      case 1:
        _mainPanelName = "Main_" + createUuid();

        if (_value.contains("tunnel"))
        {
          dyn_string tmp = _value.split("|");

          if (tmp.count() > 1)
          {
            params = makeDynString("$sectorName:" + tmp.at(1));
          }
          else
          {
            params = makeDynString("$sectorName:" + "");
          }

          _value = tmp.at(0);
        }
        if (_value.contains("gis"))
        {
          _mainPanelName = _mainPanelName + "_GIS";
        }

        nameCheck(_mainPanelName);
        PanelOffModule(_actualPanel, _mainModule);

        if (_value.contains("settings"))
        {
          params = makeDynString("$infoPanelName:" + _infoPanelName);
        }

        if (!OpenPTPanel(_value, _mainPanelName, _mainModule.ModuleName(), params))
        {
          string strServerName = getSystemName();
          //RootPanelOnModule(_value, _mainPanelName, _mainModule.ModuleName(), params);
          RootPanelOnModule(g_PanelTopologyCache[strServerName + "_PanelTopology.fileName"][1], _mainPanelName, _mainModule.ModuleName(), makeDynString()); // a basepanel cannot be loaded inside a module of the base panel!
           //OpenPTPanel(1,"", "", makeDynString());
        }
        _actualPanel = _mainPanelName;
        _naviButtons.SetInactive();
        button.SetActive(TRUE);
        GUIFaceplate::TriggerOpenFaceplate("", FALSE);
        break;

      case 2:
        moduleSize = naviModule.sizeAsDyn();
        moduleHeight = moduleSize.at(1);

        if (!_menuOpen)
        {
          newModuleSize = makeDynInt(300, moduleHeight);
          if (moduleSize != newModuleSize)
          {
            for (int i = 0; i < _naviButtons.Count(); i++)
            {
              if (getTypeName(_naviButtons.GetByIndex(i)) == "GUINaviMenuButton")
              {
                _naviButtons.GetByIndex(i).SetOpen(!_menuOpen);
              }

              _naviButtons.GetByIndex(i).SetVisible(TRUE);
            }
            setPanelSize(_naviModule.ModuleName(), rootPanel(_naviModule.ModuleName()), false, newModuleSize.at(0), newModuleSize.at(1));
            animateWait(_naviModule, "sizeAsDyn", moduleSize, newModuleSize, makeMapping("duration", 500));
          }

          _menuOpen = TRUE;
          _hideNavi.Start();
        }
        else
        {
          newModuleSize = makeDynInt(50, moduleHeight);
          if (moduleSize != newModuleSize)
          {
            animateWait(_naviModule, "sizeAsDyn", moduleSize, newModuleSize, makeMapping("duration", 500));
            setPanelSize(_naviModule.ModuleName(), rootPanel(_naviModule.ModuleName()), false, newModuleSize.at(0), newModuleSize.at(1));  //if the module size has been increased
            for (int i = 0; i < _naviButtons.Count(); i++)
            {
              if (getTypeName(_naviButtons.GetByIndex(i)) == "GUINaviMenuButton")
              {
                _naviButtons.GetByIndex(i).SetOpen(!_menuOpen);
              }
              _naviButtons.GetByIndex(i).SetVisible(FALSE);
            }
          }

          _menuOpen = FALSE;
          _hideNavi.Stop();
        }

        break;
    }
  }
  /**
   * @brief Checks if the current user is logged in.
   * @return TRUE if the user is logged in, FALSE otherwise.
   */
  private void HomePanelCB(const string &dp, const string &user)
  {
    langString descrip;
    ClickedCB(1, "none", _naviButtons.GetByIndex(0));   // sofiane: value parameter has not been used yet, that is why I set it to "none", it has nothing to sdo with Filename of the prefreed open panel.
    //ClickedCB(1, "test.pnl", _naviButtons.GetByIndex(0));
    //ClickedCB(1, "Dashboard/BuildingDashboard.xml", _naviButtons.GetByIndex(0));  //not this one
    //ClickedCB(1, "tunnel/tunnelBase.pnl", _naviButtons.GetByIndex(0));   // this was already existing

  }

  /**
   * @brief Hides the navigation menu if the cursor is not over it.
   */
  private void HideNavi()
  {
    dyn_int position = _naviModule.positionAsDyn();
    dyn_int size = _naviModule.sizeAsDyn();

    int posX, posY;
    int x, y;

    getValue("", "mapToGlobal", position.at(0), position.at(1), posX, posY);

    getCursorPosition(x, y, TRUE);

    if ((x >= posX && x <= posX + size.at(0)) && (y >= posY && y <= posY + size.at(1)))
    {
      return;
    }
    ClickedCB(2, "", nullptr);
  }
  /**
   * @brief Opens a panel on the specified module, checking if the panel is already open.
   * @param _value The value to check for the panel.
   * @param _mainPanelName The name of the main panel to open.
   * @param _mainModule The main module where the panel should be opened.
   * @param params Additional parameters for the panel.
   * @return TRUE if the panel was opened successfully, FALSE otherwise.
   */
  private bool OpenPTPanel(anytype _value, string _mainPanelName, string _mainModule, dyn_string params)
  {
    int error = pt_checkPanelTopologyCache();
    if (error < 0)
    {
      error = -1;
      return false;
    }

    if (((int)_value) == (string)_value) //is already pt pos
    {
      pt_panelOn3(_value, _naviModule.ModuleName());
      return true;
    }

    string systemPrefix = getSystemName();

//17/11/2025 removed the online value from the "_PanelTopology.**
    for (int i = 1; i <= dynlen(g_PanelTopologyCache[systemPrefix + "_PanelTopology.fileName"]); i++)
    {
      if (g_PanelTopologyCache[systemPrefix + "_PanelTopology.fileName"][i] == _value)   // not  if (g_PanelTopologyCache[systemPrefix + "_PanelTopology.fileName":_online.._value"][i] == _value)  //sofiane commented out this line for debugging!
      {
        pt_panelOn3(i, "mainModule_" + myUiNumber());
        return true;
      }
    }
    return false;
  }
};
