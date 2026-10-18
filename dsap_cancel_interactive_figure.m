function dsap_cancel_interactive_figure(figure_handle)
%DSAP_CANCEL_INTERACTIVE_FIGURE Mark user closure and release UI waits.

    if isempty(figure_handle) || ~isgraphics(figure_handle)
        return;
    end
    setappdata(figure_handle, 'UserCancelled', true);
    try
        uiresume(figure_handle);
    catch
    end
    figure_handle.CloseRequestFcn = '';
    delete(figure_handle);
    drawnow limitrate nocallbacks;
end
