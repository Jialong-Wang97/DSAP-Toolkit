function dsap_safe_delete(fig)
% Cleanup may run after a cancellation has already deleted this figure.
    if ~isempty(fig) && isgraphics(fig)
        set(fig,'CloseRequestFcn','');delete(fig);
    end
end
