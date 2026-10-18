function files=exportVesselGeometry(folder,geometry,qcFigure)
% Explicit export to a separate sidecar; never overwrites perfusion Core/CSV.
if nargin<3,qcFigure=[];end
assert(ischar(folder)||isstring(folder),'DSAP:GeometryExport','Provide an output folder.');
if ~isfolder(folder),mkdir(folder);end
files=struct('CSV',fullfile(folder,'vessel_geometry.csv'),'MAT',fullfile(folder,'vessel_geometry.mat'),'QC','');
writetable(vesselGeometryTable(geometry),files.CSV);save(files.MAT,'geometry','-v7');
if ~isempty(qcFigure)&&isgraphics(qcFigure)
 files.QC=fullfile(folder,'vessel_geometry_QC.png');exportgraphics(qcFigure,files.QC,'Resolution',140);
end
end
