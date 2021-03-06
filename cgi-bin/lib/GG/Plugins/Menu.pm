package GG::Plugins::Menu;

use base 'Mojolicious::Plugin';

our $VERSION = '0.55';
use Mojo::ByteStream;

sub register {
  my ($self, $app, $opts) = @_;

  $opts ||= {};

  $app->helper(current_alias => sub { shift->stash->{alias} || '' });

  $app->helper(menu_item  => \&menu_item);
  $app->helper(menu_track => \&menu_track);

  $app->helper(navipoint   => \&navipoint);
  $app->helper(breadcrumbs => \&breadcrumbs);
  return 1;
}

sub breadcrumbs {
  my $self = shift;

# забираем все текстовые страницы для хлебных крошек
  $self->menu_track(where => "", build_bc => 1);

  navipoint($self, @_);

  my $content
    = $self->render_to_string(template => 'plugins/menu/breadcrumbs',);

  return Mojo::ByteStream->new($content);
}

sub navipoint {
  my $self = shift;
  my @points;
  if (@_ > 0) {
    for (my $i = 0; $i <= $#_; $i += 2) {
      push @points, {'name' => $_[$i], 'url' => $_[$i + 1]};
    }
  }
  my $store = $self->stash('_navipoints') || [];

  push @$store, @points;
  $self->stash('_navipoints', $store);
  return scalar @$store;
}

sub menu_track {
  my $self   = shift;
  my %params = (
    key_razdel => 'main',
    toplevel   => 1,
    botomlevel => 4,
    parent_id  => 0,
    template   => 'top',
    where      => " AND `menu`='1' ",
    @_
  );
  $params{level} ||= $params{toplevel};

  my $stash_key = '_menu_items_' . $params{where};
  my $items     = [];
  my $levels    = {};

  $self->stash->{menu_active_levels} ||= $levels;

  if ($self->stash->{$stash_key}) {

    $items  = $self->stash->{$stash_key};
    $levels = $self->stash->{$stash_key . '_levels'};
  }
  else {

    $items = $self->app->dbi->query("
			SELECT
				`ID`, `name`, `alias`,`texts_main_"
        . $self->lang
        . "` AS `texts_main`,`url_for`,`link`,`rating`
			FROM
				`texts_main_" . $self->lang . "`
			WHERE
				`viewtext`='1' $params{where}
			ORDER BY
				`rating`, `ID`
		")->map_hashes('ID');

    my $cur_alias = lc($self->stash->{alias});

    $self->stash->{menu_active_levels} ||= {};

    foreach my $pageId (keys %$items) {
      my $row         = $items->{$pageId};
      my $parentID    = $items->{$pageId}->{texts_main};
      my $tree_levels = 1;
      my $current
        = $cur_alias && lc($items->{$pageId}->{alias}) eq $cur_alias ? 1 : 0;

      my @trees = ();

      push @trees, $pageId if $current;
      while ($parentID > 0) {
        if ($current) {

          #$levels->{$tree_levels} = $parentID;
          push @trees, $parentID;
          $items->{$parentID}->{menu_active_parent} = $current;
        }

        $tree_levels++;
        $items->{$parentID}->{noempty} = 1;


        $parentID = $items->{$parentID}->{texts_main};

      }

      if ($current) {
        my $sch = 1;
        foreach (reverse @trees) {
          $levels->{$sch++} = $_;
        }
        $self->stash->{menu_active_id} = $pageId;
        $items->{$pageId}->{menu_active} = $current;
      }


      $self->stash->{menu_active_levels} = $levels if $current;

      $items->{$pageId}->{level} = $tree_levels;
    }

    if (delete $params{build_bc}) {
      foreach my $lvl (sort keys %$levels) {
        next unless my $pageId = $levels->{$lvl};
        $self->navipoint(
          $items->{$pageId}->{name} => $self->menu_item($items->{$pageId}));
      }
    }

    $self->stash->{$stash_key}                 = $items;
    $self->stash->{$stash_key . '_levels'}     = $levels;
    $self->stash->{$stash_key . '_toplevel'}   = $params{toplevel};
    $self->stash->{$stash_key . '_botomlevel'} = $params{botomlevel};
  }

  if ($params{toplevel} > 1 and !$params{parent_id}) {
    if ($self->stash->{menu_active_levels}->{$params{toplevel} - 1}) {
      $params{parent_id}
        = $self->stash->{menu_active_levels}->{$params{toplevel} - 1};
    }
    else {
      $params{parent_id} = $self->stash->{item}->{ID};
    }
  }

  my $html = $self->render_to_string(
    levels     => $levels,
    order_ids  => $menu_order_ids,
    template   => 'plugins/menu/' . $params{template},
    _template  => $params{template},
    parent_id  => $params{parent_id},
    level      => $params{level},
    toplevel   => $params{toplevel},
    botomlevel => $params{botomlevel},
    items      => $items,
  );
  return Mojo::ByteStream->new($html);
}

sub _build_href {
  my $self  = shift;
  my @parts = @_;

  my $url = $self->prefix . '/' . join '/' => @parts;

#return $self->build('articles', $created->year, $created->month, $article->name);
  return $self->url_for('text', url => $url);
}

sub menu_item {
  my $self   = shift;
  my $params = shift;

  my $href;
  if ($params->{'link'}) {
    $href = $params->{'link'};

  }
  elsif ($params->{'url_for'}) {
    $href = $self->url_for($params->{'url_for'});

  }
  else {
    $href = $self->url_for('text', alias => $params->{'alias'});
  }
  return $href || '/';
}

1;
