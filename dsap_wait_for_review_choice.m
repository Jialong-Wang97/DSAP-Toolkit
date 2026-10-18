function choice = dsap_wait_for_review_choice(fig, prompt_text, choice_pairs)
%DSAP_WAIT_FOR_REVIEW_CHOICE Add non-modal controls to a persistent review page.
% choice_pairs is an N-by-2 cell array: {button label, returned value}.

    choice = 'closed';
    if isempty(fig) || ~isgraphics(fig)
        return;
    end
    if ~iscell(choice_pairs) || size(choice_pairs, 2) ~= 2 || isempty(choice_pairs)
        error('choice_pairs 必须是包含按钮文字和返回值的 N×2 单元数组。');
    end

    setappdata(fig, 'DSAPReviewChoice', '');
    previous_close_callback = fig.CloseRequestFcn;
    fig.CloseRequestFcn = @(source, ~) close_review_page(source);

    controls = gobjects(size(choice_pairs, 1) + 1, 1);
    controls(1) = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.095 0.96 0.045], ...
        'String', prompt_text, 'BackgroundColor', fig.Color, ...
        'HorizontalAlignment', 'center', 'FontSize', 10);

    button_count = size(choice_pairs, 1);
    gap = 0.012;
    left_margin = 0.035;
    total_width = 1 - 2 * left_margin;
    button_width = (total_width - (button_count - 1) * gap) / button_count;
    for index = 1:button_count
        x = left_margin + (index - 1) * (button_width + gap);
        return_value = choice_pairs{index, 2};
        controls(index + 1) = uicontrol(fig, 'Style', 'pushbutton', ...
            'Units', 'normalized', 'Position', [x 0.025 button_width 0.055], ...
            'String', choice_pairs{index, 1}, 'FontSize', 10, ...
            'Callback', @(~, ~) choose_review_action(fig, return_value));
    end

    figure(fig);
    drawnow;
    % A click/close can be processed by the initial drawnow. Do not start
    % a new wait after its callback has already delivered the choice.
    if isgraphics(fig) && isempty(getappdata(fig,'DSAPReviewChoice'))
        uiwait(fig);
    end

    if ~isgraphics(fig)
        return;
    end
    selected_choice = getappdata(fig, 'DSAPReviewChoice');
    if ischar(selected_choice) && ~isempty(selected_choice)
        choice = selected_choice;
    elseif isstring(selected_choice) && isscalar(selected_choice) && ...
            strlength(selected_choice) > 0
        choice = char(selected_choice);
    end

    valid_controls = controls(isgraphics(controls));
    if ~isempty(valid_controls)
        delete(valid_controls);
    end
    if isgraphics(fig)
        fig.CloseRequestFcn = previous_close_callback;
        if isappdata(fig, 'DSAPReviewChoice')
            rmappdata(fig, 'DSAPReviewChoice');
        end
        drawnow limitrate nocallbacks;
    end
end

function choose_review_action(fig, return_value)
    if isempty(fig) || ~isgraphics(fig)
        return;
    end
    setappdata(fig, 'DSAPReviewChoice', return_value);
    uiresume(fig);
end

function close_review_page(fig)
    if isempty(fig) || ~isgraphics(fig)
        return;
    end
    setappdata(fig, 'DSAPReviewChoice', 'closed');
    uiresume(fig);
    fig.CloseRequestFcn = '';
    delete(fig);
    drawnow limitrate nocallbacks;
end
