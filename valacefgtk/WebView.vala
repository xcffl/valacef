namespace CefGtk {

public class WebView : Gtk.Widget {
    public string? title {get; internal set; default = null;}
    public string? uri {get; internal set; default = null;}
    private Cef.Browser? browser = null;
    private Client? client = null;
    private Gdk.Window? event_window = null;
    private Gdk.Window? cef_window = null;
    private bool io = true;
    
    public WebView() {
        CefGtk.init();
        set_has_window(true);
		set_can_focus(true);
        add_events(Gdk.EventMask.ALL_EVENTS_MASK);
    }
    
    public override void get_preferred_width(out int minimum_width, out int natural_width) {
        minimum_width = natural_width = 100;
    }
    
    public override void get_preferred_height(out int minimum_height, out int natural_height) {
        minimum_height = natural_height = 100;
    }
    
    public override void realize() {
		cef_window = embed_cef();
        register_window(cef_window);
        
        Gtk.Allocation allocation;
        Gdk.WindowAttr attributes = {};
        get_allocation(out allocation);
        attributes.x = allocation.x;
        attributes.y = allocation.y;
        attributes.width = allocation.width;
        attributes.height = allocation.height;
        attributes.window_type = Gdk.WindowType.CHILD;
        attributes.visual = get_visual();
        attributes.event_mask = get_events()
                        | Gdk.EventMask.BUTTON_PRESS_MASK
                        | Gdk.EventMask.BUTTON_RELEASE_MASK
                        | Gdk.EventMask.KEY_PRESS_MASK
                        | Gdk.EventMask.KEY_RELEASE_MASK
                        | Gdk.EventMask.EXPOSURE_MASK
                        | Gdk.EventMask.ENTER_NOTIFY_MASK
                        | Gdk.EventMask.LEAVE_NOTIFY_MASK;
//~       attributes.wclass = Gdk.WindowWindowClass.INPUT_OUTPUT;
      attributes.wclass = Gdk.WindowWindowClass.INPUT_ONLY;
      
        if (io) {
            event_window = new Gdk.Window(
                get_parent_window(), attributes,
                Gdk.WindowAttributesType.X|Gdk.WindowAttributesType.Y/*|Gdk.WindowAttributesType.VISUAL*/);
            register_window(event_window);
            event_window.add_filter(() => Gdk.FilterReturn.CONTINUE);  // Necessary!
        }
        set_window(io ? event_window : cef_window);
        set_realized(true);
    }
    
    public override void grab_focus() {
		base.grab_focus();
		message("focus");
		if (!io && browser != null) {
            browser.get_host().set_focus(1);   
        }
	}
	
	public override bool grab_broken_event (Gdk.EventGrabBroken event) {
		message("Grab broken");
		return false;
	}

    public override bool focus_in_event(Gdk.EventFocus event) {
		message("focus_in_event");
		base.focus_in_event(event);
		return false;
	}
	
    public override bool focus_out_event(Gdk.EventFocus event) {
		message("focus_out_event");
		base.focus_out_event(event);
		return false;
	}
    
    public override bool button_press_event(Gdk.EventButton event) {
        message("button_press_event");
        if (!has_focus) {
            grab_focus();
        }
        send_click_event(event);
        return false;
    }
    
    public override bool button_release_event(Gdk.EventButton event) {
        message("button_prelease_event");
        if (!has_focus) {
            grab_focus();
        }
        send_click_event(event);
        return false;
    }
    
    public void send_click_event(Gdk.EventButton event) {
        var host = browser.get_host();
        Cef.MouseButtonType button_type;
        switch (event.button) {
        case 1:
            button_type = Cef.MouseButtonType.LEFT;
            break;
        case 2:
            button_type = Cef.MouseButtonType.MIDDLE;
            break;
        case 3:
            button_type = Cef.MouseButtonType.RIGHT;
            break;
        default:
            // Other mouse buttons are not handled here.
            return;
        }

        Cef.MouseEvent mouse = {};
        mouse.x = (int) event.x;
        mouse.y = (int) event.y;
//~         self->ApplyPopupOffset(mouse_event.x, mouse_event.y);
//~         DeviceToLogical(mouse_event, self->device_scale_factor_);
        mouse.modifiers = Keyboard.get_cef_state_modifiers(event.state);

        bool mouse_up = event.type == Gdk.EventType.BUTTON_RELEASE;
        int click_count;
        switch (event.type) {
        case Gdk.EventType.2BUTTON_PRESS:
            click_count = 2;
            break;
        case Gdk.EventType.3BUTTON_PRESS:
            click_count = 3;
            break;
        default:
            click_count = 1;
            break;
        }
        host.send_mouse_click_event(mouse, button_type, (int) mouse_up, click_count);

//~       // Save mouse event that can be a possible trigger for drag.
//~       if (!self->drag_context_ && button_type == MBT_LEFT) {
//~         if (self->drag_trigger_event_) {
//~           gdk_event_free(self->drag_trigger_event_);
//~         }
//~         self->drag_trigger_event_ =
//~             gdk_event_copy(reinterpret_cast<GdkEvent*>(event));
//~       }
    }
    
    public override bool scroll_event(Gdk.EventScroll event) {
        send_scroll_event(event);
        return false;
    }
    
    public void send_scroll_event(Gdk.EventScroll event) {
        var host = browser.get_host();
        Cef.MouseEvent mouse = {};
        mouse.x = (int) event.x;
        mouse.y = (int) event.y;
//~         self->ApplyPopupOffset(mouse_event.x, mouse_event.y);
//~         DeviceToLogical(mouse_event, self->device_scale_factor_);
        mouse.modifiers = Keyboard.get_cef_state_modifiers(event.state);

        const int SCROLLBAR_PIXELS_PER_GTK_TICK = 40;
        int dx = 0;
        int dy = 0;
        switch (event.direction) {
        case Gdk.ScrollDirection.UP:
            dy = 1;
            break;
        case Gdk.ScrollDirection.DOWN:
            dy = -1;
            break;
        case Gdk.ScrollDirection.LEFT:
            dx = 1;
            break;
        case Gdk.ScrollDirection.RIGHT:
            dx = -1;
            break;
        }
        host.send_mouse_wheel_event(mouse, dx * SCROLLBAR_PIXELS_PER_GTK_TICK, dy * SCROLLBAR_PIXELS_PER_GTK_TICK);
    }
    
    public override bool key_press_event(Gdk.EventKey event) {
        send_key_event(event);
        return false;
    }
    
    public override bool key_release_event(Gdk.EventKey event) {
        send_key_event(event);
        return false;
    }
    
    public void send_key_event(Gdk.EventKey event) {
        Cef.KeyEvent key = {};
        Keyboard.KeyboardCode windows_keycode = Keyboard.gdk_event_to_windows_keycode(event);
        key.windows_key_code = Keyboard.get_windows_keycode_without_location(windows_keycode);
        key.native_key_code = event.hardware_keycode;
        key.modifiers = Keyboard.get_cef_state_modifiers(event.state);
        if (event.keyval >= Gdk.Key.KP_Space && event.keyval <= Gdk.Key.KP_9) {
            key.modifiers |= Cef.EventFlags.IS_KEY_PAD;
        }
        if ((key.modifiers & Cef.EventFlags.ALT_DOWN) != 0) {
            key.is_system_key = 1;
        }
        if (windows_keycode == Keyboard.KeyboardCode.VKEY_RETURN) {
            // We need to treat the enter key as a key press of character \r.  This
            // is apparently just how webkit handles it and what it expects.
            key.unmodified_character = '\r';
        } else {
            // FIXME: fix for non BMP chars
            key.unmodified_character = (Cef.Char16) Gdk.keyval_to_unicode(event.keyval);
        }

        // If ctrl key is pressed down, then control character shall be input.
        if ((key.modifiers & Cef.EventFlags.CONTROL_DOWN) != 0) {
            key.character = (Cef.Char16) Keyboard.get_control_character(
                windows_keycode, (key.modifiers & Cef.EventFlags.SHIFT_DOWN) != 0);
        } else {
            key.character = key.unmodified_character;
        }
        
        var host = browser.get_host();
        if (event.type == Gdk.EventType.KEY_PRESS) {
            key.type = Cef.KeyEventType.RAWKEYDOWN;
            host.send_key_event(key);
            key.type = Cef.KeyEventType.CHAR;
            host.send_key_event(key);
        } else {
            key.type = Cef.KeyEventType.KEYUP;
            host.send_key_event(key);
        }
    }
    
    public override bool motion_notify_event(Gdk.EventMotion event) {
        send_motion_event(event);
        return false;
    }
    
    public void send_motion_event(Gdk.EventMotion event) {
        var host = browser.get_host();
        int x, y;
        Gdk.ModifierType state;
        if (event.is_hint > 0) {
            event.window.get_pointer(out x, out y, out state);
        } else {
            x = (int) event.x;
            y = (int) event.y;
            state = event.state;
            if (x == 0 && y == 0) {
                // Invalid coordinates of (0,0) appear from time to time in
                // enter-notify-event and leave-notify-event events. Sending them may
                // cause StartDragging to never get called, so just ignore these.
                return;
            }
        }

        Cef.MouseEvent mouse = {};
        mouse.x = x;
        mouse.y = y;
        // self->ApplyPopupOffset(mouse_event.x, mouse_event.y);
        // DeviceToLogical(mouse_event, self->device_scale_factor_);
        mouse.modifiers = Keyboard.get_cef_state_modifiers(state);
        bool mouse_leave = event.type == Gdk.EventType.LEAVE_NOTIFY;
        host.send_mouse_move_event(mouse, (int) mouse_leave);

//~           // Save mouse event that can be a possible trigger for drag.
//~           if (!self->drag_context_ &&
//~               (mouse_event.modifiers & EVENTFLAG_LEFT_MOUSE_BUTTON)) {
//~             if (self->drag_trigger_event_) {
//~               gdk_event_free(self->drag_trigger_event_);
//~             }
//~             self->drag_trigger_event_ =
//~                 gdk_event_copy(reinterpret_cast<GdkEvent*>(event));
//~           }
    }
    
    public override void size_allocate(Gtk.Allocation allocation) {
        base.size_allocate(allocation);
        if (event_window != null && cef_window != null) {
            cef_window.move_resize(allocation.x, allocation.y, allocation.width, allocation.height);
        }
    }
    
    private Gdk.X11.Window? embed_cef() {
		assert(CefGtk.is_initialized());
		var toplevel = get_toplevel();
		assert(toplevel.is_toplevel());
		if (toplevel.get_visual() != CefGtk.get_default_visual()) {
			error("Incompatible window visual. Use `window.set_visual(CefGtk.get_default_visual())`.");
		}
        Gtk.Allocation clip;
        get_clip(out clip);
        var parent_window = get_parent_window() as Gdk.X11.Window;
        assert(parent_window != null);
        Cef.WindowInfo window_info = {};
        window_info.parent_window = (Cef.WindowHandle) parent_window.get_xid();
        window_info.x = clip.x;
        window_info.y = clip.y;
        window_info.width = clip.width;
        window_info.height = clip.height;
        Cef.BrowserSettings browser_settings = {sizeof(Cef.BrowserSettings)};
        client = new Client(new FocusHandler(this), new DisplayHandler(this));
        Cef.String url = {};
        Cef.set_string(&url, "https://www.google.com");
        browser = Cef.browser_host_create_browser_sync(window_info, client, &url, browser_settings, null);
        var host = browser.get_host();
        host.set_focus(io ? 0 : 1);
		return new Gdk.X11.Window.foreign_for_display(
			parent_window.get_display() as Gdk.X11.Display, (X.Window) host.get_window_handle());
    }
}

} // namespace CefGtk
