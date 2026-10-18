function dsap_style_axes(ax)
% Presentation only. Never change CLim, colormap, axis limits, or plotted data.
t=dsap_theme;
ax.FontName=t.Font;ax.FontSize=t.Caption;ax.Color=t.Surface;
ax.XColor=t.TextSecondary;ax.YColor=t.TextSecondary;
ax.GridAlpha=t.GridAlpha;ax.Box='off';
ax.Title.FontName=t.Font;ax.Title.FontSize=t.Body;ax.Title.FontWeight='bold';
ax.Title.Color=t.TextPrimary;
if ~isempty(ax.Toolbar),ax.Toolbar.Visible='off';end
end
