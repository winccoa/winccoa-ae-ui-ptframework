// $License: NOLICENSE
//--------------------------------------------------------------------------------
/**
  @file $relPath
  @copyright $copyright
  @author atw121x7
*/

global const bool FACEPLATELIB_LOADED; //!< Indicates if the faceplate library is loaded.

/**
 * @brief The GUIFaceplate class provides methods to manage faceplates in the GUI.
 */
class GUIFaceplate
{
  public static dyn_function_ptr _faceplateToOpen; //!< Stores the function pointers for faceplates to be opened.
  public static dyn_function_ptr _detailsToOpen; //!< Stores the function pointers for details panel to be opened.

  /**
   * @brief The Default Constructor.
  */
  private GUIFaceplate()
  {
  }

  /**
    * @brief Get the current screen number based on the module name.
    * @param module The module name to check. Defaults to the current module name.
    * @return The screen number as an integer.
  */
public static int GetMyScreenNum(
  const string module = myModuleName()
)
{
  string tempModule = module;

  /*
   * GEDI Quick Test has no numeric module suffix.
   */
  if (module == "_QuickTest_")
  {
    return 1;
  }

  /*
   * These embedded modules already contain the logical
   * screen number in their names.
   *
   * Examples:
   * mainModule_1
   * naviModule_1
   * faceplateModule_2
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
      strsplit(module, "_");

    int iScreenNumber =
      (int)dsModuleParts.last();

    if (iScreenNumber < 1)
    {
      return 1;
    }

    return iScreenNumber;
  }

  /*
   * Original behavior for WinCC_OA modules
   * and nested panels.
   */
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

  if (iScreenNumber < 1)
  {
    return 1;
  }

  return iScreenNumber;
}
  /**
   * @brief Adds a function pointer to the list of faceplates to be opened.
   * @param faceplateToOpen The function pointer for the faceplate.
   * @param monitorNr The monitor number where the faceplate should be opened. Defaults to -1, which uses the current screen number.
  */
  public static void AddFunctionPtr(const function_ptr &faceplateToOpen, const function_ptr &datailsToOpen, int monitorNr = -1)
  {
    if (monitorNr == -1)
    {
      monitorNr = GetMyScreenNum();
    }

    _faceplateToOpen.insertAt(monitorNr - 1, faceplateToOpen);
    _detailsToOpen.insertAt(monitorNr - 1, datailsToOpen);
  }

  /**
   * @brief Triggers the opening of a faceplate on the specified panel.
   * @param panel The name of the panel where the faceplate should be opened.
   * @param open A boolean indicating whether to open (TRUE) or close (FALSE) the faceplate. Defaults to TRUE.
  */
  public static TriggerOpenFaceplate(const string &panel, const bool open = TRUE)
  {
    if (!panel.isEmpty())
    {
      triggerEvent(_faceplateToOpen.at(GetMyScreenNum()-1), panel, open);
    }
  }
  /**
   * @brief Triggers the opening of a faceplate on the specified panel.
   * @param panel The name of the panel where the faceplate should be opened.
   * @param open A boolean indicating whether to open (TRUE) or close (FALSE) the faceplate. Defaults to TRUE.
  */
  public static TriggerOpenDetails(const string &panel, const dyn_string dsParams, const bool open = TRUE)
  {
    triggerEvent(_detailsToOpen.at(GetMyScreenNum()-1), panel, dsParams, !panel.isEmpty() && open);
  }
};
