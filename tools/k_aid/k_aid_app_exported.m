classdef k_aid_app_exported < matlab.apps.AppBase

  % Properties that correspond to app components
  properties (Access = public)
    UIFigure                        matlab.ui.Figure
    UIAxes                          matlab.ui.control.UIAxes
    SelectbinnedrasterfileButton    matlab.ui.control.Button
    SiteLabelsListBox               matlab.ui.control.ListBox
    krepeatsneededEditFieldLabel    matlab.ui.control.Label
    krepeatsneededEditField         matlab.ui.control.NumericEditField
    UnitsavailableEditFieldLabel    matlab.ui.control.Label
    UnitsavailableEditField         matlab.ui.control.NumericEditField
    SitefieldsListBoxLabel          matlab.ui.control.Label
    SiteFieldsListBox               matlab.ui.control.ListBox
    BinnedsiteInfoListBoxLabel      matlab.ui.control.Label
    TrialfieldsLabel                matlab.ui.control.Label
    TrialFieldsListBox              matlab.ui.control.ListBox
    TrialLabelsListBoxLabel         matlab.ui.control.Label
    TrialLabelsListBox              matlab.ui.control.ListBox
    AnalysisfilenameEditFieldLabel  matlab.ui.control.Label
    AnalysisfilenameEditField       matlab.ui.control.EditField
    SaveanalysisButton              matlab.ui.control.Button
    SetsavedirectoryButton          matlab.ui.control.Button
    ClassifierLabel                 matlab.ui.control.Label
    ClassifierListBox               matlab.ui.control.ListBox
    PreprocessorsListBoxLabel       matlab.ui.control.Label
    PreprocessorsListBox            matlab.ui.control.ListBox
    kincludeEditFieldLabel          matlab.ui.control.Label
    kincludeEditField               matlab.ui.control.NumericEditField
    kexcludeEditFieldLabel          matlab.ui.control.Label
    kexcludeEditField               matlab.ui.control.NumericEditField
    pthresholdEditFieldLabel        matlab.ui.control.Label
    pthresholdEditField             matlab.ui.control.NumericEditField
    reportEditFieldLabel            matlab.ui.control.Label
    reportEditField                 matlab.ui.control.NumericEditField
    NDTBPathSelect                  matlab.ui.control.Button
    LoadanalysisButton              matlab.ui.control.Button
    ClassificationofEditFieldLabel  matlab.ui.control.Label
    ClassificationofEditField       matlab.ui.control.EditField
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
    editFieldEnabled = [];
  end
  
  methods (Access = private)
    
    function update_k_curve(app)
      % Update the k curve - use 'find_sites_with_k_label_reps', follow with additional exclusion based on 'binned_site_info', plot the
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
    
    
    function new_plot_label = update_plot_label(app)
      % Function called immediately prior to saving the function. Includes
      % some key information at the end of the plot label defined in the GUI
      % in parantheses for ease.
      
      % collect the current plot label.
      core_label = app.ClassificationofEditField.Value;
      
      % Collect the other numbers of interest
      reps_labels = sprintf('%d Reps', app.krepeatsneededEditField.Value);
      units_label = sprintf('%d U', length(app.available_sites));
      
      % Cycle through the preprocessors and create a combo string for those
      % enabled.
      preprocc_labels = {' Top %s features', ' Bottom %s feature removed', ' p Thres = %s'};
      var2save = app.editFieldEnabled;
      preproc_combo_label = '';
      preprocess_vals = [app.kincludeEditField.Value, app.kexcludeEditField.Value, app.pthresholdEditField.Value];
      for pp_i = 1:length(preprocc_labels)
        if var2save(pp_i) && ~(preprocess_vals(pp_i) == 0)
          preproc_combo_label = [preproc_combo_label, ',', sprintf(preprocc_labels{pp_i}, num2str(preprocess_vals(pp_i)))];
        end
      end
      
      % Combine Label features into the new plot label.
      new_plot_label = [core_label, sprintf(' (%s, %s%s)', reps_labels, units_label, preproc_combo_label)];
      
    end
  end
  

  % Callbacks that handle component events
  methods (Access = private)

    % Button pushed function: SelectbinnedrasterfileButton
    function SelectbinnedrasterfileButtonPushed(app, event)
      %       [rdfile, rdpath] = uigetfile();
      [rdfile, rdpath] = deal(0);
      
      if isnumeric(rdfile)
        disp('loading default binned data and directory')
        rdfile = 'rasterData_binned_100ms_bins_50ms_sampled';
        rdpath = 'H:\Analyzed\batchAnalysis\NeuralDecodingTB\rasterData';
      end
      
      
      figure(app.UIFigure)
      rasterData = load(fullfile(rdpath, rdfile));
      
      % Populate the app's private properties with the unique entries
      binned_site_labels = fields(rasterData.binned_site_info);
      app.site_info_fields = binned_site_labels(1:end-1);
      
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
        if ~strcmp(binned_site_labels{label_i}, 'UnitType')
          app.site_info_selected{label_i} = true(size(tmp));
        else
          % In the case of Unit type, the default decoder shouldn't
          % include MUA, as this may accidentially bias decoder.
          app.site_info_selected{label_i} = ~strcmp(tmp, 'M');
        end
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
      
      % Populate the classifier list, according to list of 3 classifier
      % which come with the package (can be made more fancy w/ pointing to
      % directory/handles, not for now though)
      app.ClassifierListBox.Items = {'max_correlation_coefficient_CL', 'poisson_naive_bayes_CL', 'libsvm_CL'};
      app.ClassifierListBox.Value = {'max_correlation_coefficient_CL'};
      
      app.PreprocessorsListBox.Items = {'zscore_normalize_FP', 'select_or_exclude_top_k_features_FP', 'select_pvalue_significant_features_FP'};
      app.PreprocessorsListBox.Value = {'zscore_normalize_FP'};
      app.editFieldEnabled = strcmp(app.PreprocessorsListBox.Items, app.PreprocessorsListBox.Value);
      
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

    % Value changed function: AnalysisfilenameEditField
    function AnalysisfilenameEditFieldValueChanged(app, event)
      value = app.AnalysisfilenameEditField.Value;
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
      
      % Update this to make sure available_sites are correct
      update_k_curve(app);
      
      % Create the analysis structure
      analysisStruct = struct();
      analysisStruct.label = app.TrialFieldsListBox.Value;
      analysisStruct.sites = app.available_sites;                       % This contains the 'site field/site label' based distinctions.
      analysisStruct.label_names_to_use = app.TrialLabelsListBox.Value;
      analysisStruct.num_cv_splits = app.krepeatsneededEditField.Value;
      analysisStruct.site_info_items = app.SiteFieldsListBox.Items;
      analysisStruct.site_info_selected = app.site_info_selected;
      analysisStruct.k_repeats_needed = app.krepeatsneededEditField.Value;
      analysisStruct.save_extra_preprocessing_info = app.reportEditField.Value;
      analysisStruct.editFieldEnabled = app.editFieldEnabled;
      
      assert(length(app.available_sites) == app.UnitsavailableEditField.Value, 'Difficulty with unit field')
      
      var2save = app.editFieldEnabled;
      
      % Add in variables depending on which analyses were specified.
      % Feature preprocessors
      preprocList = {'num_features_to_use', 'num_features_to_exclude', 'pvalue_threshold'};
      preprocParamValList = [app.kincludeEditField.Value, app.kexcludeEditField.Value, app.pthresholdEditField.Value];
      for pp_i = 1:length(preprocList)
        if var2save(pp_i)
          analysisStruct.(preprocList{pp_i}) = preprocParamValList(pp_i);
        end
      end
      
      % Classifier & Preprocessor
      analysisStruct.classifier = app.ClassifierListBox.Value;
      analysisStruct.preProc = app.PreprocessorsListBox.Value;
      
      % Quick Check on kincludeexclude - If its on, only 1 can be non-zero.
      % If both are 0 or non-0, throw an error.
      if any(strcmp(app.PreprocessorsListBox.Value, 'select_or_exclude_top_k_features_FP'))
        assert(xor(app.kincludeEditField.Value == 0, app.kexcludeEditField.Value == 0), 'if select k features is on, 1 and only 1 number must be non-0')
      end
      
      if any(strcmp(app.PreprocessorsListBox.Value, 'select_pvalue_significant_features_FP'))
        assert(app.pthresholdEditField.Value ~= 0, 'if p threshold is set, its value can not be 0')
      end
      
      % Label Augmentation for ease.
      analysisStruct.plotTitle = update_plot_label(app);
      
      % save the file to the current directory
      save(fullfile(app.saveDirPath, app.AnalysisfilenameEditField.Value), "analysisStruct")
      
    end

    % Button pushed function: SetsavedirectoryButton
    function SetsavedirectoryButtonPushed(app, event)
      %app.saveDirPath = uigetdir();
      app.saveDirPath = 0;
      
      figure(app.UIFigure)
      
      if isnumeric(app.saveDirPath)
        disp('loading default save directory')
        app.saveDirPath = 'C:\OneDrive\Lab\ESIN_Ephys_Files\Analysis\phyzzyML\buildAnalysisParamFileLib\NDT_analyses';
      end
      
      if ~isnumeric(app.saveDirPath)
        app.SetsavedirectoryButton.Enable = false;
        app.LoadanalysisButton.Enable = true;
      end
      
      if ~isempty(app.AnalysisfilenameEditField.Value) && ~isnumeric(app.saveDirPath)
        app.SaveanalysisButton.Enable = true;
      end
      
    end

    % Value changed function: PreprocessorsListBox
    function PreprocessorsListBoxValueChanged(app, event)
      value = app.PreprocessorsListBox.Value;
      
      tmp1 = any(strcmp(value, 'select_pvalue_significant_features_FP'));
      tmp2 = any(strcmp(value, 'select_or_exclude_top_k_features_FP'));
      app.editFieldEnabled = [tmp2 tmp2 tmp1];
      varInd = [tmp2 tmp2 tmp1] + 1;
      editFieldOptions = {'off', 'on'};
      
      [app.kincludeEditField.Enable, app.kexcludeEditField.Enable, app.pthresholdEditField.Enable] = deal(editFieldOptions{varInd});
      
    end

    % Button pushed function: NDTBPathSelect
    function NDTBPathSelectButtonPushed(app, event)
      %NDTBPath = uigetdir();
      NDTBPath = 0;
      
      if isnumeric(NDTBPath)
        disp('loading default NDTB directory')
        NDTBPath = 'C:\OneDrive\Lab\ESIN_Ephys_Files\Analysis\NeuralDecodingToolbox';
      end
      
      figure(app.UIFigure)
      
      if ~isempty(NDTBPath)
        addpath(genpath(NDTBPath));
        app.SelectbinnedrasterfileButton.Enable = true;
      end
      
    end

    % Button pushed function: LoadanalysisButton
    function LoadanalysisButtonPushed(app, event)
      % Button is made to load an analysis as a means of revising it or
      % generating a similar analysis more quickly or easily.
      [analysisfile, analysispath] = uigetfile(fullfile(app.saveDirPath, '*.mat'));
      figure(app.UIFigure)
      if ~isnumeric(analysispath)
        tmp = load(fullfile(analysispath, analysisfile));
        prevAnalysis = tmp.analysisStruct;
        
        % The correct way to do this: As much as possible, cycle through the fields and re-select the
        % previously selected items, populate the same fields.
        
        % The way I am doing it for the sake of saving time: Assuming these
        % fields are identical as to when the analyses were made.
        
        % Create the analysis structure
        app.TrialFieldsListBox.Value = prevAnalysis.label;
        TrialFieldsListBoxValueChanged(app, event);
        %analysisStruct.sites = app.available_sites;                       % This contains the 'site field/site label' based distinctions.
        app.TrialLabelsListBox.Value = prevAnalysis.label_names_to_use;
        app.krepeatsneededEditField.Value = prevAnalysis.num_cv_splits;
        
        % Remove the automatically added end of plotTitle prior to sticking
        % it in the field.
        endingStringStart = max(strfind(prevAnalysis.plotTitle, '('));
        app.ClassificationofEditField.Value = strtrim(prevAnalysis.plotTitle(1:endingStringStart-1));
        
        % Replace edit field w/ loaded analysisFilename
        [~, B, ~] = fileparts(analysisfile);
        app.AnalysisfilenameEditField.Value = B;
        
        % Warning here - If the items in the list are different, this may
        % cause indexing issues and unreliable results.
        if isempty(setdiff(app.SiteFieldsListBox.Items, prevAnalysis.site_info_items))
          app.site_info_selected = prevAnalysis.site_info_selected;
          app.krepeatsneededEditField.Value = prevAnalysis.k_repeats_needed;
        end
        
        app.update_k_curve()
        assert(length(app.available_sites) == app.UnitsavailableEditField.Value)
        
        preprocList = {'pvalue_threshold', 'save_extra_preprocessing_info', 'num_features_to_use', 'num_features_to_exclude'};
        preprocParamValList = {'pthresholdEditField', 'reportEditField', 'kincludeEditField', 'kexcludeEditField'};
        for pp_i = 1:length(preprocList)
          if isfield(prevAnalysis, preprocList(pp_i))
            app.(preprocParamValList{pp_i}).Value = prevAnalysis.(preprocList{pp_i});
            app.(preprocParamValList{pp_i}).Enable = true;
          end
        end
        
        % Classifier & Preprocessor, and parameter fields.
        app.ClassifierListBox.Value = prevAnalysis.classifier;
        app.PreprocessorsListBox.Value = prevAnalysis.preProc;
        app.editFieldEnabled = prevAnalysis.editFieldEnabled;

        % Update this to make sure available_sites are correct
        update_k_curve(app);
      end
    end
  end

  % Component initialization
  methods (Access = private)

    % Create UIFigure and components
    function createComponents(app)

      % Create UIFigure and hide until all components are created
      app.UIFigure = uifigure('Visible', 'off');
      app.UIFigure.Position = [100 100 646 811];
      app.UIFigure.Name = 'UI Figure';

      % Create UIAxes
      app.UIAxes = uiaxes(app.UIFigure);
      title(app.UIAxes, 'K- curve')
      xlabel(app.UIAxes, 'k value')
      ylabel(app.UIAxes, 'Units meeting criteria')
      app.UIAxes.Position = [26 427 417 367];

      % Create SelectbinnedrasterfileButton
      app.SelectbinnedrasterfileButton = uibutton(app.UIFigure, 'push');
      app.SelectbinnedrasterfileButton.ButtonPushedFcn = createCallbackFcn(app, @SelectbinnedrasterfileButtonPushed, true);
      app.SelectbinnedrasterfileButton.FontWeight = 'bold';
      app.SelectbinnedrasterfileButton.Enable = 'off';
      app.SelectbinnedrasterfileButton.Position = [462 714 158 30];
      app.SelectbinnedrasterfileButton.Text = 'Select binned raster file';

      % Create SiteLabelsListBox
      app.SiteLabelsListBox = uilistbox(app.UIFigure);
      app.SiteLabelsListBox.Items = {};
      app.SiteLabelsListBox.Multiselect = 'on';
      app.SiteLabelsListBox.ValueChangedFcn = createCallbackFcn(app, @SiteLabelsListBoxValueChanged, true);
      app.SiteLabelsListBox.Position = [461 293 158 243];
      app.SiteLabelsListBox.Value = {};

      % Create krepeatsneededEditFieldLabel
      app.krepeatsneededEditFieldLabel = uilabel(app.UIFigure);
      app.krepeatsneededEditFieldLabel.HorizontalAlignment = 'right';
      app.krepeatsneededEditFieldLabel.Position = [26 403 98 22];
      app.krepeatsneededEditFieldLabel.Text = 'k repeats needed';

      % Create krepeatsneededEditField
      app.krepeatsneededEditField = uieditfield(app.UIFigure, 'numeric');
      app.krepeatsneededEditField.ValueChangedFcn = createCallbackFcn(app, @krepeatsneededEditFieldValueChanged, true);
      app.krepeatsneededEditField.Position = [144 403 82 22];
      app.krepeatsneededEditField.Value = 1;

      % Create UnitsavailableEditFieldLabel
      app.UnitsavailableEditFieldLabel = uilabel(app.UIFigure);
      app.UnitsavailableEditFieldLabel.HorizontalAlignment = 'right';
      app.UnitsavailableEditFieldLabel.Position = [258 403 84 22];
      app.UnitsavailableEditFieldLabel.Text = 'Units available';

      % Create UnitsavailableEditField
      app.UnitsavailableEditField = uieditfield(app.UIFigure, 'numeric');
      app.UnitsavailableEditField.Editable = 'off';
      app.UnitsavailableEditField.Position = [357 403 59 22];

      % Create SitefieldsListBoxLabel
      app.SitefieldsListBoxLabel = uilabel(app.UIFigure);
      app.SitefieldsListBoxLabel.VerticalAlignment = 'top';
      app.SitefieldsListBoxLabel.FontSize = 16;
      app.SitefieldsListBoxLabel.FontWeight = 'bold';
      app.SitefieldsListBoxLabel.Position = [461 683 79 22];
      app.SitefieldsListBoxLabel.Text = 'Site fields';

      % Create SiteFieldsListBox
      app.SiteFieldsListBox = uilistbox(app.UIFigure);
      app.SiteFieldsListBox.Items = {};
      app.SiteFieldsListBox.Multiselect = 'on';
      app.SiteFieldsListBox.ValueChangedFcn = createCallbackFcn(app, @SiteFieldsListBoxValueChanged, true);
      app.SiteFieldsListBox.Position = [461 566 158 118];
      app.SiteFieldsListBox.Value = {};

      % Create BinnedsiteInfoListBoxLabel
      app.BinnedsiteInfoListBoxLabel = uilabel(app.UIFigure);
      app.BinnedsiteInfoListBoxLabel.VerticalAlignment = 'top';
      app.BinnedsiteInfoListBoxLabel.FontSize = 16;
      app.BinnedsiteInfoListBoxLabel.FontWeight = 'bold';
      app.BinnedsiteInfoListBoxLabel.Position = [461 535 85 24];
      app.BinnedsiteInfoListBoxLabel.Text = 'Site labels';

      % Create TrialfieldsLabel
      app.TrialfieldsLabel = uilabel(app.UIFigure);
      app.TrialfieldsLabel.VerticalAlignment = 'top';
      app.TrialfieldsLabel.FontSize = 16;
      app.TrialfieldsLabel.FontWeight = 'bold';
      app.TrialfieldsLabel.Position = [26 368 126 22];
      app.TrialfieldsLabel.Text = 'Trial fields';

      % Create TrialFieldsListBox
      app.TrialFieldsListBox = uilistbox(app.UIFigure);
      app.TrialFieldsListBox.Items = {};
      app.TrialFieldsListBox.ValueChangedFcn = createCallbackFcn(app, @TrialFieldsListBoxValueChanged, true);
      app.TrialFieldsListBox.Position = [26 166 169 203];
      app.TrialFieldsListBox.Value = {};

      % Create TrialLabelsListBoxLabel
      app.TrialLabelsListBoxLabel = uilabel(app.UIFigure);
      app.TrialLabelsListBoxLabel.VerticalAlignment = 'top';
      app.TrialLabelsListBoxLabel.FontSize = 16;
      app.TrialLabelsListBoxLabel.FontWeight = 'bold';
      app.TrialLabelsListBoxLabel.Position = [225 368 94 22];
      app.TrialLabelsListBoxLabel.Text = 'Trial Labels';

      % Create TrialLabelsListBox
      app.TrialLabelsListBox = uilistbox(app.UIFigure);
      app.TrialLabelsListBox.Items = {};
      app.TrialLabelsListBox.Multiselect = 'on';
      app.TrialLabelsListBox.ValueChangedFcn = createCallbackFcn(app, @TrialLabelsListBoxValueChanged, true);
      app.TrialLabelsListBox.Position = [225 166 218 203];
      app.TrialLabelsListBox.Value = {};

      % Create AnalysisfilenameEditFieldLabel
      app.AnalysisfilenameEditFieldLabel = uilabel(app.UIFigure);
      app.AnalysisfilenameEditFieldLabel.HorizontalAlignment = 'right';
      app.AnalysisfilenameEditFieldLabel.FontWeight = 'bold';
      app.AnalysisfilenameEditFieldLabel.Position = [461 267 111 22];
      app.AnalysisfilenameEditFieldLabel.Text = 'Analysis filename:';

      % Create AnalysisfilenameEditField
      app.AnalysisfilenameEditField = uieditfield(app.UIFigure, 'text');
      app.AnalysisfilenameEditField.ValueChangedFcn = createCallbackFcn(app, @AnalysisfilenameEditFieldValueChanged, true);
      app.AnalysisfilenameEditField.Position = [461 242 158 22];

      % Create SaveanalysisButton
      app.SaveanalysisButton = uibutton(app.UIFigure, 'push');
      app.SaveanalysisButton.ButtonPushedFcn = createCallbackFcn(app, @SaveanalysisButtonPushed, true);
      app.SaveanalysisButton.FontWeight = 'bold';
      app.SaveanalysisButton.Enable = 'off';
      app.SaveanalysisButton.Position = [461 185 158 22];
      app.SaveanalysisButton.Text = 'Save analysis';

      % Create SetsavedirectoryButton
      app.SetsavedirectoryButton = uibutton(app.UIFigure, 'push');
      app.SetsavedirectoryButton.ButtonPushedFcn = createCallbackFcn(app, @SetsavedirectoryButtonPushed, true);
      app.SetsavedirectoryButton.FontWeight = 'bold';
      app.SetsavedirectoryButton.Position = [461 215 158 22];
      app.SetsavedirectoryButton.Text = 'Set save directory';

      % Create ClassifierLabel
      app.ClassifierLabel = uilabel(app.UIFigure);
      app.ClassifierLabel.VerticalAlignment = 'top';
      app.ClassifierLabel.FontSize = 16;
      app.ClassifierLabel.FontWeight = 'bold';
      app.ClassifierLabel.Position = [27 134 126 22];
      app.ClassifierLabel.Text = 'Classifier';

      % Create ClassifierListBox
      app.ClassifierListBox = uilistbox(app.UIFigure);
      app.ClassifierListBox.Items = {};
      app.ClassifierListBox.Position = [27 44 178 91];
      app.ClassifierListBox.Value = {};

      % Create PreprocessorsListBoxLabel
      app.PreprocessorsListBoxLabel = uilabel(app.UIFigure);
      app.PreprocessorsListBoxLabel.VerticalAlignment = 'top';
      app.PreprocessorsListBoxLabel.FontSize = 16;
      app.PreprocessorsListBoxLabel.FontWeight = 'bold';
      app.PreprocessorsListBoxLabel.Position = [225 134 118 22];
      app.PreprocessorsListBoxLabel.Text = 'Preprocessors';

      % Create PreprocessorsListBox
      app.PreprocessorsListBox = uilistbox(app.UIFigure);
      app.PreprocessorsListBox.Items = {};
      app.PreprocessorsListBox.Multiselect = 'on';
      app.PreprocessorsListBox.ValueChangedFcn = createCallbackFcn(app, @PreprocessorsListBoxValueChanged, true);
      app.PreprocessorsListBox.Position = [225 44 152 91];
      app.PreprocessorsListBox.Value = {};

      % Create kincludeEditFieldLabel
      app.kincludeEditFieldLabel = uilabel(app.UIFigure);
      app.kincludeEditFieldLabel.HorizontalAlignment = 'right';
      app.kincludeEditFieldLabel.Position = [404 125 53 22];
      app.kincludeEditFieldLabel.Text = 'k include';

      % Create kincludeEditField
      app.kincludeEditField = uieditfield(app.UIFigure, 'numeric');
      app.kincludeEditField.Enable = 'off';
      app.kincludeEditField.Position = [497 125 87 22];

      % Create kexcludeEditFieldLabel
      app.kexcludeEditFieldLabel = uilabel(app.UIFigure);
      app.kexcludeEditFieldLabel.HorizontalAlignment = 'right';
      app.kexcludeEditFieldLabel.Position = [404 98 56 22];
      app.kexcludeEditFieldLabel.Text = 'k exclude';

      % Create kexcludeEditField
      app.kexcludeEditField = uieditfield(app.UIFigure, 'numeric');
      app.kexcludeEditField.Enable = 'off';
      app.kexcludeEditField.Position = [497 98 87 22];

      % Create pthresholdEditFieldLabel
      app.pthresholdEditFieldLabel = uilabel(app.UIFigure);
      app.pthresholdEditFieldLabel.HorizontalAlignment = 'right';
      app.pthresholdEditFieldLabel.Position = [404 71 65 22];
      app.pthresholdEditFieldLabel.Text = 'p threshold';

      % Create pthresholdEditField
      app.pthresholdEditField = uieditfield(app.UIFigure, 'numeric');
      app.pthresholdEditField.Enable = 'off';
      app.pthresholdEditField.Position = [497 71 87 22];

      % Create reportEditFieldLabel
      app.reportEditFieldLabel = uilabel(app.UIFigure);
      app.reportEditFieldLabel.HorizontalAlignment = 'right';
      app.reportEditFieldLabel.Position = [404 44 37 22];
      app.reportEditFieldLabel.Text = 'report';

      % Create reportEditField
      app.reportEditField = uieditfield(app.UIFigure, 'numeric');
      app.reportEditField.Limits = [0 1];
      app.reportEditField.Position = [497 44 87 22];

      % Create NDTBPathSelect
      app.NDTBPathSelect = uibutton(app.UIFigure, 'push');
      app.NDTBPathSelect.ButtonPushedFcn = createCallbackFcn(app, @NDTBPathSelectButtonPushed, true);
      app.NDTBPathSelect.FontWeight = 'bold';
      app.NDTBPathSelect.Position = [462 751 158 30];
      app.NDTBPathSelect.Text = 'Select NDTB Path';

      % Create LoadanalysisButton
      app.LoadanalysisButton = uibutton(app.UIFigure, 'push');
      app.LoadanalysisButton.ButtonPushedFcn = createCallbackFcn(app, @LoadanalysisButtonPushed, true);
      app.LoadanalysisButton.FontWeight = 'bold';
      app.LoadanalysisButton.Enable = 'off';
      app.LoadanalysisButton.Position = [461 156 158 22];
      app.LoadanalysisButton.Text = 'Load analysis';

      % Create ClassificationofEditFieldLabel
      app.ClassificationofEditFieldLabel = uilabel(app.UIFigure);
      app.ClassificationofEditFieldLabel.HorizontalAlignment = 'right';
      app.ClassificationofEditFieldLabel.Position = [27 13 90 22];
      app.ClassificationofEditFieldLabel.Text = 'Classification of';

      % Create ClassificationofEditField
      app.ClassificationofEditField = uieditfield(app.UIFigure, 'text');
      app.ClassificationofEditField.Position = [132 13 452 22];

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