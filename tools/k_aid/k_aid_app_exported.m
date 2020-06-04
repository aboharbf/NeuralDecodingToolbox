classdef k_aid_app_exported < matlab.apps.AppBase

  % Properties that correspond to app components
  properties (Access = public)
    UIFigure                      matlab.ui.Figure
    UIAxes                        matlab.ui.control.UIAxes
    SelectbinnedrasterfileButton  matlab.ui.control.Button
    SiteLabelsListBox             matlab.ui.control.ListBox
    krepeatsneededEditFieldLabel  matlab.ui.control.Label
    krepeatsneededEditField       matlab.ui.control.NumericEditField
    UnitsavailableEditFieldLabel  matlab.ui.control.Label
    UnitsavailableEditField       matlab.ui.control.NumericEditField
    SitefieldsListBoxLabel        matlab.ui.control.Label
    SiteFieldsListBox             matlab.ui.control.ListBox
    BinnedsiteInfoListBoxLabel    matlab.ui.control.Label
    trialfieldsListBoxLabel       matlab.ui.control.Label
    TrialFieldsListBox            matlab.ui.control.ListBox
    TrialLabelsListBoxLabel       matlab.ui.control.Label
    TrialLabelsListBox            matlab.ui.control.ListBox
    filenameLabel                 matlab.ui.control.Label
    filenameEditField             matlab.ui.control.EditField
    SaveanalysisButton            matlab.ui.control.Button
    SetsavedirectoryButton        matlab.ui.control.Button
  end

  
  properties (Access = public)
    site_fields_per_site = [];
    
    trial_labels_total = [];
    trial_labels_fields = [];
    trial_labels_field_ind = [];        % the index of the field currently selected, allows for updating of other structures.
    trial_labels_unique = [];
    trial_labels_selected = [];
    
    site_info_fields = [];           % The fields describing the kind of info each site has (e.g. 'grid hole')
    site_info_field_ind = [];        % the index of the field currently selected, allows for updating of other structures.
    site_info_labels = [];           % the labels describing the specific instance of a field a site has. (e.g. 'A2')
    site_info_selected = [];         % a cell array of logical matricies matching site_info_labels, describing which has been selected for counting.
    
    k_line_handle = [];
    possible_units = [];
    plot_pop_switch = false;
    available_sites = [];
    
    saveDirPath = []
  end
  
  methods (Access = private)
    
    function update_k_curve(app)
      % Update the k curve - use 'find_sites_with_k_label_reps', follow
      % with additional exclusion based on 'binned_site_info', plot the
      % resulting curve.
      
      
      label_names_to_use = app.TrialLabelsListBox.Value;
      the_labels = app.trial_labels_total.(app.TrialFieldsListBox.Value);
      k = app.krepeatsneededEditField.Value;
      
      [available_sites_tmp, min_num_repeats_all_sites, num_repeats_matrix, ds.label_names_to_use] = find_sites_with_k_label_repetitions(the_labels, k, label_names_to_use);
      
       if ~isempty(available_sites_tmp)
        % Remove sites based on 'binned_info' criteria, update
        % 'available_sites'
        
        % Turn this available_sites into logical
        available_sites_logic = false(size(num_repeats_matrix,1),1)';
        available_sites_logic(available_sites_tmp) = true;
        
        % Generate a logical of sites which meet the 'site_label'
        % criteria. first by generating the array for every label, then
        % combining.
        binned_site_logical = false(size(app.site_fields_per_site));
        for label_i = 1:length(app.SiteFieldsListBox.Items)
          binned_site_logical(label_i,:) = ismember(app.site_fields_per_site(label_i,:), app.site_info_labels{label_i}(app.site_info_selected{label_i}));
        end
        
        binned_site_logical = [binned_site_logical; available_sites_logic];
        
        % Find sites which check all the desired boxes.
        site_select_ind = (sum(binned_site_logical) == size(binned_site_logical,1));
        app.available_sites = find(site_select_ind);
        % Update the outputs of find_k_repeats to be reflected in the plot
        % below
        min_num_repeats_all_sites(~site_select_ind) = 0;
        
      end
            
      % Plot the k-curve
      % If you want to know how many of your units you can use, it is useful to
      % plot some distribution showing how many units you will have for each k.
      if app.plot_pop_switch
        cla(app.UIAxes)
      end
      inds_of_sites_with_at_least_k_repeats = find(min_num_repeats_all_sites >= k);
      sorted_min_reps = sort(min_num_repeats_all_sites);
      possible_k = 1:sorted_min_reps(end);
      app.possible_units = arrayfun(@(x) sum(sorted_min_reps >= possible_k(x)), possible_k);
      plot(app.UIAxes, possible_k, app.possible_units, 'color', 'k')
      hold(app.UIAxes, "on")
      xlabel(app.UIAxes, 'Possible Repeats of set')
      ylabel(app.UIAxes, 'Units with X Repeats')
      
      % Draw a new line of relationship b/t k selected and repetitions
      % available.
      
      % Draw line in response to changed plot
      update_k_line(app)
      app.plot_pop_switch = true;
    end
    
    
    function update_k_line(app)
      k = app.krepeatsneededEditField.Value;
      hold(app.UIAxes, 'on')
      if isempty(app.k_line_handle) || ~isvalid(app.k_line_handle)
        app.k_line_handle = plot(app.UIAxes, [k k], ylim(app.UIAxes), 'LineWidth', 3, 'color', 'r');
      else
        app.k_line_handle.XData = [k k];
      end
      if ~isempty(app.possible_units) && (length(app.possible_units) >= k)
        app.UnitsavailableEditField.Value = app.possible_units(k);
      else
        app.UnitsavailableEditField.Value = 0;
      end
    end
  end
  

  % Callbacks that handle component events
  methods (Access = private)

    % Button pushed function: SelectbinnedrasterfileButton
    function SelectbinnedrasterfileButtonPushed(app, event)
      [rdfile, rdpath] = uigetfile();
      
      rasterData = load(fullfile(rdpath, rdfile));
      
      % Populate the app's private properties with the unique entries
      tmp = fields(rasterData.binned_site_info);
      app.site_info_fields = tmp(1:end-1);
      
      tmp_site_info_labels = struct2cell(rasterData.binned_site_info);
      tmp_site_info_labels = tmp_site_info_labels(1:end-1);
      app.site_info_labels = cell(size(tmp_site_info_labels));
      app.site_fields_per_site = cell(length(app.site_info_fields), length(tmp_site_info_labels{1}));      % Generate an array which will be used as a matrix when comparing
      % units.
      
      for label_i = 1:length(tmp_site_info_labels)
        % Store into larger matrix
        tmp = tmp_site_info_labels{label_i};
        if iscell(tmp)
          app.site_fields_per_site(label_i, :) = tmp;
        else
          app.site_fields_per_site(label_i, :) = deal(mat2cell(num2str(tmp), ones(length(tmp),1)));
        end
        
        tmp = unique(tmp);
        app.site_info_selected{label_i} = true(size(unique(tmp)));
        
        if iscell(tmp)
          app.site_info_labels{label_i} = tmp;
        else
          app.site_info_labels{label_i} = mat2cell(num2str(tmp), ones(length(tmp),1));
        end
        
      end
      
      % Populate the GUI with the appropriate stuff for the default item
      % Site info stats
      app.SiteFieldsListBox.Items = app.site_info_fields;
      app.SiteFieldsListBox.Value = app.SiteFieldsListBox.Items(1);
      SiteFieldsListBoxValueChanged(app)
      app.UIAxes.Title.String = sprintf('K-curve - %d Total Units', length(tmp_site_info_labels{1}));
      
      % Trial info stats
      app.trial_labels_fields = fields(rasterData.binned_labels);              % the fields of the binned labels struct, specifying per trial info
      app.trial_labels_unique = cell(size(app.trial_labels_fields));          % the per trial labels in each site, unique elements.
      for lab_i = 1:length(app.trial_labels_fields)
        allLabels = rasterData.binned_labels.(app.trial_labels_fields{lab_i});
        switch class(allLabels{1})
          case {'cell', 'string'}
            
            if size(allLabels{1},1) == 1
              app.trial_labels_unique{lab_i} = unique([allLabels{:}]);
            else
              app.trial_labels_unique{lab_i} = unique(vertcat(allLabels{:}));
            end
            
          case 'double'
            tmp = unique([allLabels{:}]);
            if size(tmp,1) == 1
              tmp = tmp';
            end
            app.trial_labels_unique{lab_i} = mat2cell(num2str(tmp), ones(length(tmp),1));
        end
        app.trial_labels_selected{lab_i} =  true(size(app.trial_labels_unique{lab_i}));
        
      end
      
      app.TrialFieldsListBox.Items = app.trial_labels_fields;
      app.TrialFieldsListBox.Value = app.TrialFieldsListBox.Items(1);
      app.trial_labels_total = rasterData.binned_labels;
      TrialFieldsListBoxValueChanged(app); % Also Update the k_curve for the default values
      
      % Turn off the button
      app.SelectbinnedrasterfileButton.Enable = false;
    end

    % Value changed function: SiteFieldsListBox
    function SiteFieldsListBoxValueChanged(app, event)
      value = app.SiteFieldsListBox.Value;
      
      % find the index of the value in the list
      valInd = strcmp(app.SiteFieldsListBox.Items, value);
      app.site_info_field_ind = valInd;
      % use that index to populate the labels box from the
      % app.site_info_labels
      app.SiteLabelsListBox.Items = app.site_info_labels{valInd};
      
      % 'select' the ones which were selected in the
      % app.site_info_selected
      app.SiteLabelsListBox.Value = app.SiteLabelsListBox.Items(app.site_info_selected{valInd});
      
    end

    % Value changed function: SiteLabelsListBox
    function SiteLabelsListBoxValueChanged(app, event)
      value = app.SiteLabelsListBox.Value;
      
      % If these values are changed, update the app.site_info_selected
      % logical indicies
      new_binned_site_info_selected = false(size(app.SiteLabelsListBox.Items));
      [~, B] = intersect(app.SiteLabelsListBox.Items, value);
      new_binned_site_info_selected(B) = true;
      app.site_info_selected{app.site_info_field_ind} = new_binned_site_info_selected;
      
      % Trigger the update the k curve function.
      update_k_curve(app)
      
    end

    % Value changed function: TrialFieldsListBox
    function TrialFieldsListBoxValueChanged(app, event)
      value = app.TrialFieldsListBox.Value;
      
      % find the index of the value in the list
      valInd = strcmp(app.TrialFieldsListBox.Items, value);
      app.trial_labels_field_ind = valInd;
      
      % use that index to populate the labels box from the originally
      % constructed list of unique entries, and set the value correctly
      app.TrialLabelsListBox.Items = app.trial_labels_unique{valInd};
      app.TrialLabelsListBox.Value = app.TrialLabelsListBox.Items(app.trial_labels_selected{valInd});
      
      % Trigger the update the k curve function.
      update_k_curve(app)
    end

    % Value changed function: krepeatsneededEditField
    function krepeatsneededEditFieldValueChanged(app, event)
      update_k_line(app)
    end

    % Value changed function: TrialLabelsListBox
    function TrialLabelsListBoxValueChanged(app, event)
      value = app.TrialLabelsListBox.Value;
      update_k_curve(app);
    end

    % Value changed function: filenameEditField
    function filenameEditFieldValueChanged(app, event)
      value = app.filenameEditField.Value;
      if ~isempty(value) && ~isempty(app.saveDirPath)
        app.SaveanalysisButton.Enable = true;
      end
    end

    % Button pushed function: SaveanalysisButton
    function SaveanalysisButtonPushed(app, event)
      % Function saves the analyses detailed in the app at the moment to a
      % file which can be read in by the NDT to specific it.
      
      if isempty(app.available_sites)
        error('Sites to use are empty, specify different analysis')
      end
      
      analysisStruct = struct();
      analysisStruct.label = app.TrialFieldsListBox.Value;
      analysisStruct.sites = app.available_sites;                       % This contains the 'site field/site label' based distinctions.
      analysisStruct.label_names_to_use = app.TrialLabelsListBox.Value;
      analysisStruct.num_cv_splits = app.krepeatsneededEditField.Value;
      
      % save the file to the current directory
      save(fullfile(app.saveDirPath, app.filenameEditField.Value), "analysisStruct")
      
    end

    % Button pushed function: SetsavedirectoryButton
    function SetsavedirectoryButtonPushed(app, event)
      app.saveDirPath = uigetdir();
      if ~isempty(app.saveDirPath)
        app.SetsavedirectoryButton.Enable = false;
      end
      
      if ~isempty(app.filenameEditField.Value) && ~isempty(app.saveDirPath)
        app.SaveanalysisButton.Enable = true;
      end
      
    end
  end

  % Component initialization
  methods (Access = private)

    % Create UIFigure and components
    function createComponents(app)

      % Create UIFigure and hide until all components are created
      app.UIFigure = uifigure('Visible', 'off');
      app.UIFigure.Position = [100 100 635 624];
      app.UIFigure.Name = 'UI Figure';

      % Create UIAxes
      app.UIAxes = uiaxes(app.UIFigure);
      title(app.UIAxes, 'K- curve')
      xlabel(app.UIAxes, 'k value')
      ylabel(app.UIAxes, 'Units meeting criteria')
      app.UIAxes.Position = [26 240 417 367];

      % Create SelectbinnedrasterfileButton
      app.SelectbinnedrasterfileButton = uibutton(app.UIFigure, 'push');
      app.SelectbinnedrasterfileButton.ButtonPushedFcn = createCallbackFcn(app, @SelectbinnedrasterfileButtonPushed, true);
      app.SelectbinnedrasterfileButton.FontWeight = 'bold';
      app.SelectbinnedrasterfileButton.Position = [468 559 151 30];
      app.SelectbinnedrasterfileButton.Text = 'Select binned raster file';

      % Create SiteLabelsListBox
      app.SiteLabelsListBox = uilistbox(app.UIFigure);
      app.SiteLabelsListBox.Items = {};
      app.SiteLabelsListBox.Multiselect = 'on';
      app.SiteLabelsListBox.ValueChangedFcn = createCallbackFcn(app, @SiteLabelsListBoxValueChanged, true);
      app.SiteLabelsListBox.Position = [461 107 158 273];
      app.SiteLabelsListBox.Value = {};

      % Create krepeatsneededEditFieldLabel
      app.krepeatsneededEditFieldLabel = uilabel(app.UIFigure);
      app.krepeatsneededEditFieldLabel.HorizontalAlignment = 'right';
      app.krepeatsneededEditFieldLabel.Position = [26 216 98 22];
      app.krepeatsneededEditFieldLabel.Text = 'k repeats needed';

      % Create krepeatsneededEditField
      app.krepeatsneededEditField = uieditfield(app.UIFigure, 'numeric');
      app.krepeatsneededEditField.ValueChangedFcn = createCallbackFcn(app, @krepeatsneededEditFieldValueChanged, true);
      app.krepeatsneededEditField.Position = [144 216 82 22];
      app.krepeatsneededEditField.Value = 1;

      % Create UnitsavailableEditFieldLabel
      app.UnitsavailableEditFieldLabel = uilabel(app.UIFigure);
      app.UnitsavailableEditFieldLabel.HorizontalAlignment = 'right';
      app.UnitsavailableEditFieldLabel.Position = [258 216 84 22];
      app.UnitsavailableEditFieldLabel.Text = 'Units available';

      % Create UnitsavailableEditField
      app.UnitsavailableEditField = uieditfield(app.UIFigure, 'numeric');
      app.UnitsavailableEditField.Editable = 'off';
      app.UnitsavailableEditField.Position = [357 216 59 22];

      % Create SitefieldsListBoxLabel
      app.SitefieldsListBoxLabel = uilabel(app.UIFigure);
      app.SitefieldsListBoxLabel.VerticalAlignment = 'top';
      app.SitefieldsListBoxLabel.FontSize = 16;
      app.SitefieldsListBoxLabel.FontWeight = 'bold';
      app.SitefieldsListBoxLabel.Position = [461 533 79 16];
      app.SitefieldsListBoxLabel.Text = 'Site fields';

      % Create SiteFieldsListBox
      app.SiteFieldsListBox = uilistbox(app.UIFigure);
      app.SiteFieldsListBox.Items = {};
      app.SiteFieldsListBox.Multiselect = 'on';
      app.SiteFieldsListBox.ValueChangedFcn = createCallbackFcn(app, @SiteFieldsListBoxValueChanged, true);
      app.SiteFieldsListBox.Position = [461 410 158 118];
      app.SiteFieldsListBox.Value = {};

      % Create BinnedsiteInfoListBoxLabel
      app.BinnedsiteInfoListBoxLabel = uilabel(app.UIFigure);
      app.BinnedsiteInfoListBoxLabel.VerticalAlignment = 'top';
      app.BinnedsiteInfoListBoxLabel.FontSize = 16;
      app.BinnedsiteInfoListBoxLabel.FontWeight = 'bold';
      app.BinnedsiteInfoListBoxLabel.Position = [461 387 85 16];
      app.BinnedsiteInfoListBoxLabel.Text = 'Site labels';

      % Create trialfieldsListBoxLabel
      app.trialfieldsListBoxLabel = uilabel(app.UIFigure);
      app.trialfieldsListBoxLabel.VerticalAlignment = 'top';
      app.trialfieldsListBoxLabel.FontSize = 16;
      app.trialfieldsListBoxLabel.FontWeight = 'bold';
      app.trialfieldsListBoxLabel.Position = [26 181 126 22];
      app.trialfieldsListBoxLabel.Text = 'trial fields';

      % Create TrialFieldsListBox
      app.TrialFieldsListBox = uilistbox(app.UIFigure);
      app.TrialFieldsListBox.Items = {};
      app.TrialFieldsListBox.ValueChangedFcn = createCallbackFcn(app, @TrialFieldsListBoxValueChanged, true);
      app.TrialFieldsListBox.Position = [26 17 169 165];
      app.TrialFieldsListBox.Value = {};

      % Create TrialLabelsListBoxLabel
      app.TrialLabelsListBoxLabel = uilabel(app.UIFigure);
      app.TrialLabelsListBoxLabel.VerticalAlignment = 'top';
      app.TrialLabelsListBoxLabel.FontSize = 16;
      app.TrialLabelsListBoxLabel.FontWeight = 'bold';
      app.TrialLabelsListBoxLabel.Position = [225 181 94 22];
      app.TrialLabelsListBoxLabel.Text = 'Trial Labels';

      % Create TrialLabelsListBox
      app.TrialLabelsListBox = uilistbox(app.UIFigure);
      app.TrialLabelsListBox.Items = {};
      app.TrialLabelsListBox.Multiselect = 'on';
      app.TrialLabelsListBox.ValueChangedFcn = createCallbackFcn(app, @TrialLabelsListBoxValueChanged, true);
      app.TrialLabelsListBox.Position = [225 17 218 165];
      app.TrialLabelsListBox.Value = {};

      % Create filenameLabel
      app.filenameLabel = uilabel(app.UIFigure);
      app.filenameLabel.HorizontalAlignment = 'right';
      app.filenameLabel.Position = [465 76 58 22];
      app.filenameLabel.Text = 'filename: ';

      % Create filenameEditField
      app.filenameEditField = uieditfield(app.UIFigure, 'text');
      app.filenameEditField.ValueChangedFcn = createCallbackFcn(app, @filenameEditFieldValueChanged, true);
      app.filenameEditField.Position = [524 76 100 22];

      % Create SaveanalysisButton
      app.SaveanalysisButton = uibutton(app.UIFigure, 'push');
      app.SaveanalysisButton.ButtonPushedFcn = createCallbackFcn(app, @SaveanalysisButtonPushed, true);
      app.SaveanalysisButton.FontWeight = 'bold';
      app.SaveanalysisButton.Enable = 'off';
      app.SaveanalysisButton.Position = [468 17 151 22];
      app.SaveanalysisButton.Text = 'Save analysis';

      % Create SetsavedirectoryButton
      app.SetsavedirectoryButton = uibutton(app.UIFigure, 'push');
      app.SetsavedirectoryButton.ButtonPushedFcn = createCallbackFcn(app, @SetsavedirectoryButtonPushed, true);
      app.SetsavedirectoryButton.FontWeight = 'bold';
      app.SetsavedirectoryButton.Position = [468 47 151 22];
      app.SetsavedirectoryButton.Text = 'Set save directory';

      % Show the figure after all components are created
      app.UIFigure.Visible = 'on';
    end
  end

  % App creation and deletion
  methods (Access = public)

    % Construct app
    function app = k_aid_app_exported

      % Create UIFigure and components
      createComponents(app)

      % Register the app with App Designer
      registerApp(app, app.UIFigure)

      if nargout == 0
        clear app
      end
    end

    % Code that executes before app deletion
    function delete(app)

      % Delete UIFigure when app is deleted
      delete(app.UIFigure)
    end
  end
end