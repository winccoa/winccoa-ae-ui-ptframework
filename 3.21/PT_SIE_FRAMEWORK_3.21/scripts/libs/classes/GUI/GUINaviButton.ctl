// $License: NOLICENSE
//--------------------------------------------------------------------------------
/**
 @file $relPath
 @brief This file contains the definition of the GUINaviButton class.
 @details The GUINaviButton class represents a navigation button in a graphical user interface.
 @copyright $copyright
 @author n.holzersoellner
 */

/**
 * @brief Represents a navigation button in a graphical user interface.
 */
class GUINaviButton
{
  private shape _iconRef; //!< The reference to the shape representing the button's icon.
  private shape _textRef; //!< The reference to the shape representing the button's text.
  public shape _frameSelector; //!< The reference to the shape representing the button's frame selector.   // tmr, I will make  a getter method for it'!
  private shape _panelRef;
  private shape shPanel;
  private shape shChildNodeSpacer;
  private shape shParentNavi;
  private string sRefName;
  //private shape _childNavi; //!< The reference to the shape representing the button's frame selector.
  private shared_ptr<GUINaviButton> _button; //!< A shared pointer to another GUINaviButton object, allowing for interaction between buttons.

  private string _currentBackColor; //!< The current background color of the button.

  private const string colorGhost = "color-ghost"; //!< The default ghost color for the button.
  private const string colorGhostHover = "color-ghost--hover"; //!< The hover color for the button when it is not selected.
  private const string colorGhostSelected = "color-ghost--selected"; //!< The selected color for the button when it is active.
  private const string colorPrimary = "color-primary"; //!< The primary color for the button when it is active.
  private const string colorText = "color-soft-text"; //!< The default text color for the button.
  private const string colorTextHover = "color-std-text"; //!< The text color when the button is hovered over.
   private langString lsCurrentText;
  /**
   * @brief Default constructor for GUINaviButton class.
   * @param textRef The reference to the shape representing the button's text.
   * @param iconRef The reference to the shape representing the button's icon.
   * @param frameSelector The reference to the shape representing the button's frame selector.
   */

  public GUINaviButton(const shape &textRef, const shape &iconRef, const shape &frameSelector)
  {
    _textRef = textRef;
    _iconRef = iconRef;
    _frameSelector = frameSelector;
    shPanel = _frameSelector.panel;
    sRefName = _frameSelector.refName;
    _panelRef = getShape(shPanel.moduleName + "." +  rootPanel(shPanel.moduleName) + ":" + _frameSelector.refName);
    shChildNodeSpacer = getShape("childNavi");
    shParentNavi      = getShape("parentNavi");
  }

#event ClickedEvent(int mode, anytype value, shared_ptr<GUINaviButton> button) //!< Event triggered when the button is clicked.

  /**
   * @brief Sets the hover color of the button.
   * @param hover A boolean indicating whether the button is being hovered over.
   */
  public void SetHoverColor(const bool &hover)
  {
    _frameSelector.backCol((hover) ? colorGhostHover : _currentBackColor);
    _textRef.SetForeColor((hover) ? colorTextHover : colorText);
  }

  /**
   * @brief Sets the active state of the button.
   * @param active A boolean indicating whether the button is active.
   */
  public void SetActive(const bool &active)
  {
    _currentBackColor = (active) ? colorGhostSelected : colorGhost;
    _frameSelector.backCol(_currentBackColor);
    _iconRef.SetSelBackCol((active) ? colorPrimary : colorGhost);
  }

  /**
   * @brief Sets the icon of the button.
   * @param fill The fill string for the button's icon.
   */
  public void SetIcon(const string &fill)
  {
    _iconRef.SetIcon(fill);
  }

  /**
   * @brief Sets the text of the button.
   * @param text The text to be displayed on the button.
   */
  public void SetText(const langString &text)
  {
    if (shapeExists("textRef"))
      _textRef.SetText(text);

    lsCurrentText = text;

  }

   public void DisplayCurrentText()
  {
    if (shapeExists("textRef"))
      _textRef.SetText(lsCurrentText);
    DebugN("display function:", lsCurrentText, (string) lsCurrentText, self.name());
  }


  /**
   * @brief Sets the visibility of the button text.
   * @param visible A boolean indicating whether the button is visible.
   */
  public void SetVisible(const bool &visible)
  {
    if (shapeExists("textRef"))
      _textRef.SetVisible(visible);
  }

  /**
   * @brief Sets the visibility of the button text.
   * @param visible A boolean indicating whether the button is visible.
   */
  public void SetRefVisible(const bool &visible)
  {
    shape shPanel = _frameSelector.panel;
    setValue(shPanel.moduleName + "." +  rootPanel(shPanel.moduleName) + ":" + _frameSelector.refName, "visible", visible);

    if (!visible)  //change "-" to "+"
      setValue(shPanel.moduleName + "." +  rootPanel(shPanel.moduleName) + ":" + _frameSelector.refName + ".parentNavi", "text", "+ ");

  }

  /**
   * @brief Handles the button click event.
   * @details Throws an error indicating that the Clicked function is not defined.
   */
  public void Clicked()
  {
    throw (makeError("", PRIO_SEVERE, ERR_PARAM, 0, "Clicked Function not defined."));
  }

  /**
   * @brief Sets the pointer to another GUINaviButton object.
   * @param button A shared pointer to the GUINaviButton object.
   */
  public void SetPointer(shared_ptr<GUINaviButton> button)
  {
    assignPtr(_button, button);
  }

  /**
   * @brief Gets the pointer to another GUINaviButton object.
   * @return A shared pointer to the GUINaviButton object.
   */
  public shared_ptr<GUINaviButton> GetPointer()
  {
    return _button;
  }

  public shape getChildNavi()
  {
    return shChildNodeSpacer; //getShape(shPanel, "childNavi");
  }

  public shape getParentNavi()
  {
    return shParentNavi;
  }

};
