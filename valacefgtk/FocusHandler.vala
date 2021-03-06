namespace CefGtk {

public class FocusHandler : Cef.FocusHandlerRef {
    public FocusHandler(WebView web_view) {
        base();
        priv_set<unowned WebView>("web_view", web_view);
        /**
         * Called when the browser component is about to loose focus. For instance, if
         * focus was on the last HTML element and the user pressed the TAB key. |next|
         * will be true (1) if the browser is giving focus to the next component and
         * false (0) if the browser is giving focus to the previous component.
         */
        vfunc_on_take_focus = (self, /*Browser*/ browser, /*int*/ next) => {
            Cef.assert_browser_ui_thread();
            message("on_take_focus %d", next);
        };

        /**
         * Called when the browser component is requesting focus. |source| indicates
         * where the focus request is originating from. Return false (0) to allow the
         * focus to be set or true (1) to cancel setting the focus.
         */
        vfunc_on_set_focus = (self, /*Browser*/ browser, /*FocusSource*/ source) => {
            Cef.assert_browser_ui_thread();
            return source == Cef.FocusSource.NAVIGATION ? 1 : 0;
        };

        /**
         * Called when the browser component has received focus.
         */
        vfunc_on_got_focus = (self, /*Browser*/ browser) => {
            Cef.assert_browser_ui_thread();
            ((FocusHandler) self).priv_get<unowned WebView>("web_view").grab_focus();
        };
    }
}

} // namespace CefGtk
