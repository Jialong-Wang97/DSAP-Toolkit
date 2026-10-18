function dsap_workspace_text(control,value)
if isprop(control,'Text'),control.Text=value;else,control.String=value;end
end
