package GG::Admin::Banners;

use utf8;

use Mojo::Base 'GG::Admin::AdminController';

sub _init {
  my $self = shift;

  $self->def_program('banners');

  $self->get_keys(
    type       => ['lkey', 'button'],
    controller => $self->app->program->{key_razdel}
  );

  my $config = {
    controller_name => $self->app->program->{name},

    #controller		=> 'keys',
  };

  $self->stash->{list_table} ||= 'data_banner';

  $self->stash($_, $config->{$_}) foreach (keys %$config);

  $self->stash->{index} ||= $self->send_params->{index};

  unless ($self->send_params->{replaceme}) {
    $self->send_params->{replaceme} = $self->stash->{controller};
    $self->send_params->{replaceme} .= '_' . $self->stash->{list_table}
      if $self->stash->{list_table};
  }

  #$self->send_params->{replaceme} .= $self->stash->{index} || '';

  foreach (qw(list_table replaceme)) {
    $self->param_default($_ => $self->send_params->{$_})
      if $self->send_params->{$_};
  }

  $self->stash->{replaceme} = $self->send_params->{replaceme};
  $self->stash->{lkey}      = $self->stash->{controller};
  $self->stash->{lkey} .= '_' . $self->send_params->{list_table}
    if $self->send_params->{list_table};
  $self->stash->{script_link}
    = '/admin/' . $self->stash->{controller} . '/body';

  $self->stash->{folder} = '/image/bb/';
}

sub body {
  my $self = shift;

  $self->_init;

  my $do = $self->param('do');

  given ($do) {

    when ('list_container') { $self->list_container; }

    when ('delete_file') {
      $self->field_delete_file(fields => [qw(folder docfile type_file size)]);
    }

    when ('upload') {
      my $item = $self->getArraySQL(
        from  => $self->stash->{list_table},
        where => "`ID`='" . $self->stash->{index} . "'"
      );
      $self->file_download(path => $self->stash->{folder} . $item->{docfile});
    }

    default {
      $self->default_actions($do);
    }
  }
}

sub lists_select {
  my $self = shift;

  my $lfield = $self->param('lfield');
  $lfield =~ s{^fromselect}{};
  my $keystring = $self->param('keystring');

  my $selected_vals = $self->send_params->{$lfield};
  $selected_vals =~ s{=}{,}gi;

  my $sch      = 0;
  my $list_out = "";

  my $where = "`ID` > 0";
  $where .= " AND `name` LIKE '%$keystring%' ORDER BY `name`";

  my (@array_lang);
  foreach ($self->dbi->getTablesSQL()) {
    if ($_ =~ m/texts_main_([\w]+)/) { push(@array_lang, $1); }
  }

  # Смотрим в разделах:
  for my $item (
    $self->dbi->query(
      "SELECT `ID`,`name`,`key_razdel` FROM `lst_texts` WHERE $where")->hashes
    )
  {
    my $name = &def_name_list_select("Раздел: ", $item->{name});
    my $index = "$$item{key_razdel}:0";
    $list_out
      .= "lstobj[out].options[lstobj[out].options.length] = new Option('$name', '$index');\n"
      if $name;

    $sch++;
  }

  foreach my $l (@array_lang) {
    for my $item (
      $self->dbi->query(
        "SELECT `ID`,`name` FROM `texts_main_${l}` WHERE $where")->hashes
      )
    {
      my $name
        = &def_name_list_select("Страница ($l): ", $item->{name});

      my $index = "$l:main:$$item{ID}";
      $list_out
        .= "lstobj[out].options[lstobj[out].options.length] = new Option('$name', '$index');\n"
        if $name;

      $sch++;
    }
  }
  $list_out
    .= "document.getElementById('ok_' + out).innerHTML = \"<span style='background-color:lightgreen;width:45px;padding:3px'>найдено: "
    . $sch
    . "</span>\";\n";
  $self->render(text => $list_out);

  sub def_name_list_select {
    my ($title, $name) = @_;

    $name =~ s/&laquo;/"/;
    $name =~ s/&raquo;/"/;
    $name =~ s/["']+//g;

    return $title . $name;
  }

}

sub tree {
  my $self = shift;

  my $controller = $self->stash->{controller};
  my $table      = $self->stash->{list_table};

  $self->stash->{param_default} .= "&first_flag=1";

  $self->param_default('replaceme' => '');

  my $folders = $self->getHashSQL(
    select => "`ID`,`name`",
    from   => 'data_banner_advert_block',
    where  => "`ID`>0",
    sys    => 1
  ) || [];

  foreach my $i (0 .. $#$folders) {
    $folders->[$i]->{replaceme} = 'replaceme',    #$table.$folders->[$i]->{ID};
      $folders->[$i]->{click_type} = 'list_filtered',
      $folders->[$i]->{params} = {id_advert_block => $folders->[$i]->{ID}};
  }

  my $items = $self->getHashSQL(
    select => "`ID`,`name`",
    from   => 'data_banner',
    where  => "`id_advert_block`=''"
  );

  foreach my $i (0 .. $#$items) {
    $items->[$i]->{icon}      = 'image';
    $items->[$i]->{replaceme} = $controller . '_' . $table . $items->[$i]->{ID};
    $items->[$i]->{name}
      = "[" . $items->[$i]->{ID} . "] " . $items->[$i]->{name};
    $items->[$i]->{param_default} = "&replaceme=" . $items->[$i]->{replaceme};
  }

  $self->render(
    folders  => $folders,
    items    => $items,
    template => 'admin/tree_block'
  );
}

sub tree_block {
  my $self = shift;

  my $items      = [];
  my $index      = $self->stash->{index};
  my $controller = $self->stash->{controller};
  my $table      = $self->stash->{list_table};

  $self->param_default('replaceme' => '');

  my $banner_place
    = "(`id_advert_block`='$index' OR (`id_advert_block` LIKE '$index=%' OR `id_advert_block` LIKE '%=$index=%' OR `id_advert_block` LIKE '%=$index'))";

  $items = $self->getHashSQL(
    select => "`ID`,`name`",
    from   => $table,
    where  => "$banner_place ORDER BY `name` ",
  ) || [];

  foreach my $i (0 .. $#$items) {
    $items->[$i]->{name}
      = "[" . $items->[$i]->{ID} . "] " . $items->[$i]->{name};
    $items->[$i]->{icon}      = 'image';
    $items->[$i]->{replaceme} = $controller . '_' . $table . $items->[$i]->{ID};
    $items->[$i]->{param_default} = "&replaceme=" . $items->[$i]->{replaceme};
  }

  $self->render(
    json => {
      content => $self->render_to_string(
        items    => $items,
        template => 'admin/tree_elements'
      ),
      items => [
        {
          type  => 'eval',
          value => "treeObj['" . $self->stash->{controller} . "'].initTree();"
        },
      ]
    }
  );

}

sub save {
  my $self   = shift;
  my %params = @_;

  if ($self->param('list_page'))
  {    # Сохранение выбранных страниц
    my $list_page = $self->param('list_page');
    $list_page =~ s/,/\n/g;
    $list_page .= "\n";
    $self->send_params->{list_page} = $list_page;
  }

  $self->backup_doptable;

  unless ($self->stash->{index}) {
    $self->send_params->{'week'} = '-1';
    $self->send_params->{'time'} = '-1';
  }

  if ($self->save_info(%params, table => $self->stash->{list_table})) {

    if ($self->send_params->{docfile}) {
      $self->getArraySQL(
        select => "`ID`,`docfile`,`type_file`",
        from   => $self->stash->{list_table},
        where  => "`ID`='" . $self->stash->{index} . "'",
        stash  => 'tmp'
      );

# Изменяем размер баннера под выбранное баннерное место
      if ( $self->stash->{tmp}->{docfile}
        && $self->send_params->{width}
        && $self->send_params->{height})
      {
        my $img_ext = [qw(jpg jpeg gif png)];

        my $lkeyFolder = $self->lkey(name => 'docfile', setting => 'folder');
        my $type_file = lc($self->stash->{tmp}->{type_file});

        if (grep { $type_file eq $_ } @$img_ext) {
          $self->resize_pict(
            crop    => 1,
            quality => 100,
            file    => $self->static_path
              . $lkeyFolder
              . $self->stash->{tmp}->{docfile},
            width  => $self->send_params->{width},
            height => $self->send_params->{height},
            retina => $self->lkey(name => 'docfile', setting => 'retina'),
          );
        }
      }
    }

    if ($params{continue}) {
      $self->admin_msg_success("Данные сохранены");
      return $self->edit;
    }
    elsif ($self->stash->{group} >= $#{$self->app->program->{groupname}} + 1) {
      return $self->info;
    }
    $self->stash->{group}++;
  }

  if ($self->stash->{dop_table}) {
    $self->restore_doptable;
    return $self->render(
      json => {
        content => $self->has_errors ? "ERROR" : "OK",
        items => $self->init_dop_tablelist_reload(),
      }
    );
  }

  return $self->edit;

}

sub info {
  my $self   = shift;
  my %params = @_;

  my $table = $self->stash->{list_table};

  if ($self->send_params->{flag_add}) {
    $self->def_context_menu(lkey => 'add_info');
  }
  else {
    $self->def_context_menu(lkey => 'print_info');
  }

  if ($self->stash->{index}) {
    $self->getArraySQL(
      from  => $self->stash->{list_table},
      where => "`ID`='" . $self->stash->{index} . "'",
      stash => 'anketa'
    );

    $self->def_list_page if $self->stash->{anketa}->{list_page};
  }

  $self->define_anket_form(access => 'r', table => $table, noget => 1);
}

sub def_list_page {
  my $self      = shift;
  my $list_page = $self->stash->{anketa}->{list_page};
  return unless $list_page;

  my $labels    = {};
  my $list      = {};
  my @list_page = ();

  $list_page =~ s/\r//g;
  foreach my $lp (split(/\n/, $list_page)) {
    my $name_select = '';
    if ($lp) {
      push(@list_page, $lp);
      my ($l, $r, $id) = split(/:/, $lp);
      if ($r =~ m/\d/ && $r == 0) {
        my $item
          = $self->dbi->query(
          "SELECT `name` FROM `lst_texts` WHERE `key_razdel`='$l' LIMIT 0,1")
          ->hash;
        $name_select = "Раздел: " . $$item{name};
      }
      else {
        my $item
          = $self->dbi->query(
          "SELECT `name` FROM `texts_${r}_${l}` WHERE `ID`='$id' LIMIT 0,1")
          ->hash;
        $name_select = "Страница ($l): " . $$item{name};
      }
      $labels->{$lp} = $name_select;
      $list->{$lp}   = $name_select;
    }
  }
  $self->lkey(name => 'list_page')->{list} = $list;
  $self->_def_list_labels($self->lkey(name => 'list_page'));

  $self->stash->{anketa}->{list_page} = join("=", @list_page);
}

sub edit {
  my $self   = shift;
  my %params = @_;

  $self->def_context_menu(lkey => 'edit_info');

  if ($self->stash->{dop_table}) {
    $self->backup_doptable();
  }

  if ($self->stash->{index}) {
    $self->getArraySQL(
      from  => $self->stash->{list_table},
      where => "`ID`='" . $self->stash->{index} . "'",
      stash => 'anketa'
    );

    $self->def_list_page if $self->stash->{anketa}->{list_page};

    if ( $self->stash->{group} == 2
      && $self->stash->{anketa}->{id_advert_block}
      && !$self->stash->{anketa}->{width}
      && !$self->stash->{anketa}->{height})
    {
      my @placesIds = split('=', $self->stash->{anketa}->{id_advert_block});
      my $place
        = $self->dbi->query(
            "SELECT * FROM `data_banner_advert_block` WHERE `ID`='"
          . $placesIds[0]
          . "' AND `width`!='' AND `height`!=''")->hash;

      $self->stash->{anketa}->{width}  = $place->{width};
      $self->stash->{anketa}->{height} = $place->{height};
    }
  }
  else {
    $self->stash->{anketa}->{langs} = 'ru';
  }

  $self->define_anket_form(access => 'w', noget => 1);
}

sub list_container {
  my $self   = shift;
  my %params = @_;

  $self->delete_list_items if $self->stash->{delete};
  $self->hide_list_items(lfield => 'view') if $self->param('hide');
  $self->show_list_items(lfield => 'view') if $self->param('show');

  $self->stash->{enter} = 1 if $params{enter};

  my $list_table = $self->stash->{list_table};

  $self->stash->{win_name}
    = $self->program_table_title($self->stash->{list_table}) || 'Список';

  if ($list_table eq 'data_banner') {
    $self->def_context_menu(lkey => 'table_list');

  }
  elsif ($list_table eq 'data_banner_advert_block') {
    $self->def_context_menu(lkey => 'table_list_view');

  }
  elsif ($list_table eq 'data_banner_advert_users') {
    $self->def_context_menu(lkey => 'table_list');

  }

  $self->stash->{listfield_groups_buttons} = {
    delete => "удалить",
    show   => 'публиковать',
    hide   => 'скрыть'
  };

  return $self->list_items(%params, container => 1);
}

sub list_items {
  my $self   = shift;
  my %params = @_;

  my $list_table = $self->stash->{list_table};
  $self->render_not_found unless $list_table;

  $self->stash->{listfield_buttons} = [qw(delete edit print)];

  $params{table} = $list_table;

  $self->define_table_list(%params);
}

1;
