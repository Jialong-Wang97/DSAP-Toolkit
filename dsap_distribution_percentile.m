function q=dsap_distribution_percentile(x,p)
% MATLAB midpoint empirical quantiles: sorted observations at (k-.5)/n.
% Base-MATLAB fallback shared by every metric (no Statistics dependency).
x=sort(double(x(:)));p=double(p);q=nan(size(p));n=numel(x);if n==0,return;end
t=max(1,min(n,n*p/100+.5));lo=floor(t);hi=ceil(t);a=t-lo;
q=reshape((1-a(:)).*x(lo(:))+a(:).*x(hi(:)),size(p));
end
