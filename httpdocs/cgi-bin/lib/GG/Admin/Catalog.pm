package GG::Admin::Catalog;

use utf8;

use Mojo::Base 'GG::Admin::AdminController';

sub _init{
	my $self = shift;

	$self->def_program('catalog');

	$self->get_keys( type => ['lkey', 'button'], controller => $self->app->program->{key_razdel});

	my $config = {
		controller_name	=> $self->app->program->{name},
		#controller		=> 'keys',
	};

	$self->stash->{list_table} ||= 'data_catalog_items';

	$self->stash($_, $config->{$_}) foreach (keys %$config);

	$self->stash->{index} ||= $self->send_params->{index};

	unless($self->send_params->{replaceme}){
		$self->send_params->{replaceme} = $self->stash->{controller};
		$self->send_params->{replaceme} .= '_'.$self->stash->{list_table} if $self->stash->{list_table};
	}
	#$self->send_params->{replaceme} .= $self->stash->{index} || '';

	foreach ( qw(list_table replaceme)){
		$self->param_default($_ => $self->send_params->{$_} ) if $self->send_params->{$_};
	}

	$self->stash->{replaceme} = $self->send_params->{replaceme};
	$self->stash->{lkey} = $self->stash->{controller};
	$self->stash->{lkey} .= '_'. $self->send_params->{list_table} if $self->send_params->{list_table};
	$self->stash->{script_link} = '/admin/'.$self->stash->{controller}.'/body';

	if($self->stash->{list_table} =~ /data_catalog_([\s\S]+)/){
		$self->app->program->{groupname} = $self->app->program->{settings}->{'groupname_'.$1} if($1 && $self->app->program->{settings}->{'groupname_'.$1});
	}


}

sub body{
	my $self = shift;

	$self->_init;

	my $do = $self->param('do');

	given ($do){

		when('list_container') 			{ $self->list_container; }
		when('enter') 					{ $self->list_container( enter => 1); }
		when('list_items') 				{ $self->list_items; }

		when('print') 					{ $self->print_choose; }
		when('print_anketa') 			{
			$self->print_anketa(
				title 	=> "Раздел «".$self->stash->{name_razdel}."»",
			);
		}

		when('delete_pict') 			{ $self->field_delete_pict( render => 1, fields => [$self->send_params->{lfield}]); }
		when('field_upload_swf') 		{ $self->field_upload_swf; }
		when('file_upload_tmp') 		{ $self->render( text => $self->file_upload_tmp ); }

		when('menu_button') 			{
			$self->def_menu_button(
				key 		=> $self->app->program->{menu_btn_key},
				controller	=> $self->app->program->{key_razdel},
			);
		}

		when('filter_take') 			{ $self->filter_take( render => 1); }
		when('quick_view') 				{ $self->quick_view; }

		when('set_qedit') 				{ $self->set_qedit; }
		when('set_qedit_i') 			{ $self->set_qedit(info => 1); }
		when('save_qedit') 				{ $self->save_qedit; }
		when('save_qedit_i') 			{ $self->save_qedit; }

		when('filter') 					{ $self->filter_form; }
		when('filter_save') 			{ $self->filter_save; }
		when('filter_clear') 			{ $self->filter_clear();  $self->list_container(); }

		when('add') 					{ $self->edit( add => 1); }
		when('edit') 					{ $self->edit; }
		when('info') 					{ $self->info; }
		when('save') 					{ $self->save; }
		when('delete') 					{ $self->delete; }
		when('restore') 				{ $self->save( restore => 1); }

		when('restore') 				{ $self->save( restore => 1); }

		when('lists_select') 			{ $self->lists_select; }

		# Загрузка архива
		when('zipimport')	 			{ $self->zipimport; }
		when('zipimport_save')	 		{ $self->zipimport_save; }
		when('zipimport_save_pict')	 	{ $self->zipimport_save_pict; }

		default							{ $self->render( text => "действие не определенно"); }
	}
}

sub zipimport{
	my $self = shift;

	$self->param_default('lfield' => 'pict');

	my @keys = qw(zip);
	push @keys, $self->stash->{dir_field};

	$self->param_default('list_table' => 'dtbl_catalog_items_images' );
	$self->param_default('id_item' => $self->send_params->{id_item} );

	$self->define_anket_form(template => 'anketa_zipimport', access => 'w', render_html => 1, keys => \@keys);
}

sub zipimport_save{
	my $self = shift;

	my $files = $self->file_extract_zip( path => $self->file_tmpdir.$self->send_params->{zip} );

	my $html = $self->render( files => $files, template => 'Admin/Plugins/File/zipimport_img_node', partial => 1);

	$self->render( json => {html => $html, count => scalar(@$files)});
}

sub zipimport_save_pict{
	my $self = shift;

	my $lfield = $self->send_params->{lfield};

	if($self->file_save_pict(
		filename 	=> $self->send_params->{filename},
		lfield		=> $lfield,
	)){
		my $vals = {
			name	=> $self->send_params->{filename},
			rating	=> 99,
			id_item =>
		};

		$self->save_info(table => $self->stash->{list_table}, field_values => $vals );
	};

	my $item = $self->dbi->query("SELECT `pict` FROM `".$self->stash->{list_table}."` WHERE `ID`='".$self->stash->{index}."'")->hash;

	my $folder = $self->lfield_folder( lfield => $lfield ) || $item->{folder};
	$self->render( json => {filename	=> $item->{pict}, src => $folder.$item->{pict} });
}

sub lists_select{
	my $self = shift;

	my $lfield = $self->param('lfield');
	$lfield =~ s{^fromselect}{};
	my $keystring = $self->param('keystring');

	my $selected_vals = $self->send_params->{$lfield};
	$selected_vals =~ s{=}{,}gi;

	my $sch = 0;
	my $list_out = "";

	my $where  = "`ID` > 0";
	   $where .= " AND `name` LIKE '%$keystring%' ORDER BY `name`";

	my (@array_lang);
	foreach ($self->dbi->getTablesSQL()) { if ($_ =~ m/texts_main_([\w]+)/) {push(@array_lang, $1);} }

	# Смотрим в разделах:
	for my $item ($self->dbi->query("SELECT `ID`,`name`,`key_razdel` FROM `lst_texts` WHERE $where")->hashes){
		my $name  = &def_name_list_select("Раздел: ", $item->{name});
		my $index = "$$item{key_razdel}:0";
		$list_out .= "lstobj[out].options[lstobj[out].options.length] = new Option('$name', '$index');\n" if $name;

		$sch++;
	}

	foreach my $l (@array_lang) {
		for my $item ($self->dbi->query("SELECT `ID`,`name` FROM `texts_main_${l}` WHERE $where")->hashes){
			my $name  = &def_name_list_select("Страница ($l): ", $item->{name});

			my $index = "$l:main:$$item{ID}";
			$list_out .= "lstobj[out].options[lstobj[out].options.length] = new Option('$name', '$index');\n" if $name;

			$sch++;
		}
	}
	$list_out .= "document.getElementById('ok_' + out).innerHTML = \"<span style='background-color:lightgreen;width:45px;padding:3px'>найдено: ".$sch."</span>\";\n";
	$self->render( text => $list_out);

	sub def_name_list_select {
		my ($title, $name) = @_;

		$name =~ s/&laquo;/"/;
		$name =~ s/&raquo;/"/;
		$name =~ s/["']+//g;

		return $title.$name;
	}

}


sub delete{
	my $self = shift;

	$self->backup_doptable;

	if ($self->getArraySQL( from => $self->stash->{list_table}, where => $self->stash->{index}, stash => 'anketa')) {

		if($self->stash->{dop_table}){
			if($self->delete_info( from => $self->stash->{list_table}, where => $self->stash->{index})){
				if($self->stash->{anketa}->{pict}){
					$self->file_delete_pict(
						lfield => 'pict',
						folder => $self->lkey(name => 'pict' )->{settings}->{folder},
						pict => $self->stash->{anketa}->{pict}
					);
				}

				$self->restore_doptable;
				return $self->field_dop_table_reload;
			}
		}

		if($self->delete_info( from => $self->stash->{list_table}, where => $self->stash->{index} )){

			if($self->stash->{anketa}->{pict}){
				$self->file_delete_pict(
					lfield 	=> 'pict',
					folder 	=> $self->lkey(name => 'pict' )->{settings}->{folder},
					pict 	=> 	$self->stash->{anketa}->{pict}
				);
			}


			$self->stash->{tree_reload} = 1;

			$self->save_logs( 	name 	=> 'Удаление записи из таблицы '.$self->stash->{list_table},
								comment	=> "Удалена запись из таблицы [".$self->stash->{index}."]. Таблица ".$self->stash->{list_table});

			$self->define_anket_form( noget => 1, access => 'd', table => $self->stash->{list_table});

		}

	} else {

	$self->save_logs( 	name 	=> 'Попытка удаления записи из таблицы '.$self->stash->{list_table},
						comment	=> "Неудачная попытка удаления записи из таблицы [".$self->stash->{index}."]. Таблица ".$self->stash->{list_table}.". ".$self->msg_no_wrap);

	$self->block_null;
	}

}


sub copy{
	my $self = shift;

	unless(
			$self->getArraySQL(
				from 	=> $self->stash->{list_table},
				where	=> "`ID`='".$self->stash->{index}."'",
				stash	=> 'anketa'
			)
		){
		$self->admin_msg_errors("Перед созданием копии необходимо сохранить текущий объект");

		return $self->edit;
	}
	my $index = delete $self->stash->{'index'};

	my $anketa = delete $self->stash->{anketa};
	$self->send_params({});
	foreach my $f (keys %$anketa){
		next if($f eq 'ID' or $f eq 'alias' or $f eq 'pict');

		$self->send_params->{$f} = $anketa->{$f};
	}

	$self->stash->{group} = 1;

	if( $self->save_info( table => $self->stash->{list_table}) ){
		my $copiedIndex = $self->stash->{'index'};

		# Копируем сложные поля
		if($anketa->{pict}){
			my $lkeyFolder = $self->lkey(name => 'pict', controller => 'catalog', setting => 'folder');
			my $folder = $self->app->static->paths->[0].$lkeyFolder;
			my $filetmp = $self->file_copy_tmp($folder.$anketa->{pict});

			$self->file_save_pict(
				filename 	=> $filetmp,
				lfield		=> 'pict',
				fields		=> {pict => 'pict'},
			);
		}

		# копируем измерения
		for my $features ($self->dbi->query("SELECT * FROM `dtbl_catalog_items_features` WHERE `id_item`='$index' ORDER BY `rating`")->hashes){
			delete $features->{ID};
			$features->{id_item} = $copiedIndex;

			$self->dbi->insert_hash('dtbl_catalog_items_features', %$features);
		}

		# копируем доп фото
		for my $images ($self->dbi->query("SELECT * FROM `dtbl_catalog_items_images` WHERE `id_item`='$index' ORDER BY `rating`")->hashes){
			delete $images->{ID};
			$images->{id_item} = $copiedIndex;

			my $imgId = $self->dbi->insert_hash('dtbl_catalog_items_images', %$images);

			my $lkeyFolder = $self->lkey(name => 'pict', controller => 'catalog', setting => 'folder');
			my $folder = $self->app->static->paths->[0].$lkeyFolder;
			my $filetmp = $self->file_copy_tmp($folder.$anketa->{pict});

			$self->file_save_pict(
				filename 	=> $filetmp,
				lfield		=> 'pict',
				fields		=> {pict => 'pict'},
			);
		}

		$self->admin_msg_success("Объект успешно скопирован");
		return $self->edit;
	}

	$self->admin_msg_errors("Ошибка создании копии");
	return $self->edit;
}


sub save{
	my $self = shift;
	my %params = @_;

	my $table = $self->stash->{list_table};

	$self->backup_doptable;

	$self->stash->{index} = 0 if $params{restore};

	if( $self->save_info( table => $self->stash->{list_table}) ){

		if($params{restore}){
			$self->stash->{tree_reload} = 1;
			$self->save_logs( 	name 	=> 'Восстановление записи в таблице '.$self->stash->{list_table},
								comment	=> "Восстановлена запись в таблице [".$self->stash->{index}."]. Таблица ".$self->stash->{list_table}.". ".$self->msg_no_wrap);
			return $self->info;
		}

		$self->file_save_pict( 	filename 	=> $self->send_params->{pict},
								lfield		=> 'pict',
								fields		=> {pict => 'pict'},
								) if $self->send_params->{pict};

		if(!$self->stash->{dop_table} && $self->stash->{group} >= $#{$self->app->program->{groupname}} + 1){
			return $self->info;
		}
		$self->stash->{group}++;
	}

	if($self->stash->{dop_table}){
		$self->restore_doptable;
		return $self->render( json => {
				content	=> $self->has_errors ? "ERROR" : "OK",
				items	=> $self->init_dop_tablelist_reload(),
		});
	}

	return $self->edit;

}

sub info{
	my $self = shift;
	my %params = @_;

	my $table = $self->stash->{list_table};

	if ($self->send_params->{flag_add}) {
		$self->def_context_menu( lkey => 'add_info');
	} else {
		$self->def_context_menu( lkey => 'print_info');
	}

	if($self->stash->{index}){
		$self->getArraySQL(	from 	=> $self->stash->{list_table},
							where	=> "`ID`='".$self->stash->{index}."'",
							stash	=> 'anketa');
	}

	$self->define_anket_form( access => 'r', table => $table, noget => 1);
}

sub edit{
	my $self = shift;
	my %params = @_;

	$self->def_context_menu( lkey => 'edit_info');

	if($self->stash->{dop_table}){
		$self->backup_doptable();
	}

	if($self->stash->{index}){
		$self->getArraySQL(	from 	=> $self->stash->{list_table},
							where	=> "`ID`='".$self->stash->{index}."'",
							stash	=> 'anketa');

	}


	$self->define_anket_form( access => 'w', noget => 1);
}

sub list_container{
	my $self = shift;
	my %params = @_;

	$self->delete_list_items if $self->stash->{delete};
	$self->hide_list_items( lfield => 'active') 		if $self->param('hide');
	$self->show_list_items( lfield => 'active') 		if $self->param('show');

	$self->stash->{enter} = 1 if ($params{enter});

	$self->def_context_menu( lkey => 'table_list');

	if($self->stash->{list_table} eq 'data_catalog_orders'){
		$self->stash->{win_name} = "Список заказов";

	} elsif($self->stash->{list_table} eq 'data_catalog_categorys'){
		$self->stash->{win_name} = "Список категорий";

	} else {
		$self->stash->{win_name} = "Список товаров";
	}

	$self->stash->{listfield_groups_buttons} = {delete => "удалить", show => 'публиковать', hide => 'скрыть'};

	return $self->list_items(%params, container => 1)
}

sub list_items{
	my $self = shift;
	my %params = @_;

	my $list_table = $self->stash->{list_table};
	$self->render_not_found unless $list_table;

	$self->stash->{listfield_buttons} =  [qw(delete edit print)];

	$params{table} = $list_table;

	$self->define_table_list(%params);
}

1;