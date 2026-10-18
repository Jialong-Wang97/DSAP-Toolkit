function band=dsap_validate_cranial_limits(limits,image_size)
% Shared validation for the manually confirmed intracranial band.
    valid=isstruct(limits)&&isscalar(limits)&& ...
        all(isfield(limits,{'Method','UpperRow','LowerRow'}));
    if valid
        valid=(ischar(limits.Method)||(isstring(limits.Method)&&isscalar(limits.Method))) && ...
            strcmp(limits.Method,'manual-horizontal-cranial-limits') && ...
            isnumeric(limits.UpperRow)&&isreal(limits.UpperRow)&&isscalar(limits.UpperRow) && ...
            isnumeric(limits.LowerRow)&&isreal(limits.LowerRow)&&isscalar(limits.LowerRow);
    end
    if valid
        values=[limits.UpperRow limits.LowerRow];
        valid=all(isfinite(values)) && all(values==round(values)) && ...
            values(1)>=1 && values(2)<=image_size(1) && values(1)<=values(2);
    end
    if ~valid
        error('DSAP:ManualCranialLimitsRequired','必须先手动确认有效的颅内上下限。');
    end
    band=false(image_size);band(limits.UpperRow:limits.LowerRow,:)=true;
end
