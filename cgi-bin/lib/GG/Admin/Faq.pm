package GG::Admin::Faq;

use utf8;

use Mojo::Base 'GG::Admin::AdminController';

sub _init {
  my $self = shift;

  $self->def_program('faq');

  $self->get_keys(
    type       => ['lkey', 'button'],
    controller => $self->app->program->{key_razdel}
  );

  my $config = {
    controller_name => $self->app->program->{name},

    #controller		=> 'keys',
  };

  $self->stash->{list_table} ||= 'data_faq';

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
}

sub body {
  my $self = shift;

  $self->_init;

  my $do = $self->param('do');

  given ($do) {

    when ('list_container') { $self->list_container; }

    default {
      $self->default_actions($do);
    }
  }
}

sub save {
  my $self   = shift;
  my %params = @_;

  my $table = $self->stash->{list_table};

  $self->backup_doptable;

  if ($self->save_info(%params, table => $self->stash->{list_table})) {

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
  }

  $self->define_anket_form(access => 'r', table => $table, noget => 1);
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

  }


  $self->app->lkeys->{quest}->{settings}->{group} = $self->stash->{group};


  $self->define_anket_form(access => 'w', noget => 1);
}

sub list_container {
  my $self   = shift;
  my %params = @_;

  $self->delete_list_items if $self->stash->{delete};

  $self->stash->{enter} = 1 if ($params{enter});

  $self->def_context_menu(lkey => 'table_list');

  $self->stash->{win_name} = "Список";

  $self->stash->{listfield_groups_buttons} = {delete => "удалить"};

  return $self->list_items(%params, container => 1);
}

sub list_items {
  my $self   = shift;
  my %params = @_;

  my $list_table = $self->stash->{list_table};
  $self->render_not_found unless $list_table;

  $params{table} = $list_table;

  $self->define_table_list(%params);
}

1;
