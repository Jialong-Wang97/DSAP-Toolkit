function row=dsap_roi_image_row(y,rows)
% UI/suggestion coordinates only: preserve the historical image-y -> row rule.
assert(isscalar(y)&&isreal(y)&&isfinite(y)&&y>=.5&&y<=rows+.5, ...
 'DSAP:DraftLimits','点击超出 DSA 图像行范围。');
row=max(1,min(rows,round(y)));
end
