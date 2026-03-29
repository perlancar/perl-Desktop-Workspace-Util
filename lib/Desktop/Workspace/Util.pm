package Desktop::Workspace::Util;

use 5.010001;
use strict 'subs', 'vars';
use warnings;
use Log::ger;

use Exporter qw(import);

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(
                       get_desktop_workspace_module
                       instantiate_desktop_workspace_module
                       list_desktop_workspace_items
                       open_desktop_workspace_items
               );

our %SPEC;

our %argspec0_module = (
    module => {
        schema => 'perl::modname*',
        req => 1,
        pos => 0,
    },
);

our %argspecopt_ns_prefixes = (
    ns_prefixes => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'ns_prefix',
        summary => 'List of namespaces to search for a Desktop Workspace specification modules',
        schema => ['array*', of=>'perl::modname'],
        default => ['DesktopWorkspace'],
    },
);

our %argspecs_module = (
    %argspec0_module,
    %argspecopt_ns_prefixes,
);

our %argspecopt_module_args = (
    module_args => {
        schema => 'hash*',
    },
);

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Utilities related to DesktopWorkspace',
};

$SPEC{get_desktop_workspace_module} = {
    v => 1.1,
    summary => 'Get the first Perl desktop workspace specification module',
    args => {
        %argspecs_module,
    },
    result_naked => 1,
};
sub get_desktop_workspace_module {
    my %args = @_;

    my $module      = $args{module} or die "Please specify 'module'";
    my $ns_prefixes = $args{ns_prefixes} // ["DesktopWorkspace"];

    push @$ns_prefixes, "" unless @$ns_prefixes;

    for my $ns_prefix (@$ns_prefixes) {
        my $mod = "$ns_prefix\::$module";
        (my $mod_pm = "$mod.pm") =~ s!::!/!g;
        if (eval { require $mod_pm; 1 }) {
            return $mod;
        }
    }
    die "Can't find desktop workspace specification module '$module' (searched in ". join(", ", @$ns_prefixes).")";
}

$SPEC{instantiate_desktop_workspace_module} = {
    v => 1.1,
    summary => 'Instantiate the desktop workspace specification module (class)',
    args => {
        %argspecs_module,
        %argspecopt_module_args,
    },
    result_naked => 1,
};
sub instantiate_desktop_workspace_module {
    my %args = @_;

    my $mod = get_desktop_workspace_module(
        module => $args{module}, ns_prefixes => $args{ns_prefixes});
    $mod->new(%{ $args{module_args} // {} });
}

$SPEC{list_desktop_workspace_items} = {
    v => 1.1,
    summary => 'List the items from desktop workspace specification module, with filtering options',
    args => {
        %argspecs_module,
        %argspecopt_module_args,

        all => {
            summary => 'Whether to include items that are not included by default (has property `include_by_default`=0)',
            schema => 'bool*',
            tags => ['category:filtering'],
        },
        include_any_tags => {
            summary => 'Include all items that have any tag specified',
            schema => ['array*', of=>'str*'],
            tags => ['category:filtering'],
        },
        include_all_tags => {
            summary => 'Include all items that have ALL tags specified',
            schema => ['array*', of=>'str*'],
            tags => ['category:filtering'],
        },
        exclude_any_tags => {
            summary => 'Exclude all items that have any tags specified',
            schema => ['array*', of=>'str*'],
            tags => ['category:filtering'],
        },
        exclude_all_tags => {
            summary => 'Exclude all items that have ALL tags specified',
            schema => ['array*', of=>'str*'],
            tags => ['category:filtering'],
        },
        include_url => {
            summary => 'Whether to include URL items',
            schema => ['bool*'],
            tags => ['category:filtering'],
        },
        include_file => {
            summary => 'Whether to include file items',
            schema => ['bool*'],
            tags => ['category:filtering'],
        },
        include_dir => {
            summary => 'Whether to include dir items',
            schema => ['bool*'],
            tags => ['category:filtering'],
        },
        include_prog => {
            summary => 'Whether to include program items',
            schema => ['bool*'],
            tags => ['category:filtering'],
        },
        query => {
            schema => ['array*', of=>'str*'],
            pos => 1,
            slurpy => 1,
            tags => ['category:filtering'],
        },

        detail => {
            schema => 'bool*',
            cmdline_aliases => {l=>{}},
            tags => ['category:result'],
        },
        shuffle => {
            schema => 'bool*',
            tags => ['category:result'],
        },
    },
};
sub list_desktop_workspace_items {
    my %args = @_;

    my $obj = instantiate_desktop_workspace_module(
        module => $args{module},
        ns_prefixes => $args{ns_prefixes},
        module_args => $args{module_args},
    );

    my $items = $obj->items;

    if ($args{shuffle}) {
        require List::Util;
        $items = [List::Util::shuffle(@$items)];
    }

    require List::Util::Find;
    my @filtered_items;
  ITEM:
    for my $i (0 .. $#{$items}) {
        my $item = $items->[$i];

        # if not included by default, will be included only if specifically matching a filter
        my $include_by_default = $args{all} ? 1 :
            ($item->{include_by_default} // 1);

        my $match_a_filter = 0;

      FILTER: {
          INCLUDE_ANY_TAGS: {
                last unless $args{include_any_tags} && @{ $args{include_any_tags} };
                do { log_debug "Skipping item %s: does not pass include_any_tags %s", $item, $args{include_any_tags}; next ITEM }
                    unless List::Util::Find::hasanystrs($args{include_any_tags}, @{ $item->{tags} // []});
                $match_a_filter++;
            }
          INCLUDE_ALL_TAGS: {
                last unless $args{include_all_tags} && @{ $args{include_all_tags} };
                do { log_debug "Skipping item %s: does not pass include_all_tags %s", $item, $args{include_all_tags}; next ITEM }
                    unless List::Util::Find::hasallstrs($args{include_all_tags}, @{ $item->{tags} // []});
                $match_a_filter++;
            }
          EXCLUDE_ANY_TAGS: {
                last unless $args{exclude_any_tags} && @{ $args{exclude_any_tags} };
                do { log_debug "Skipping item %s: does not pass exclude_any_tags %s", $item, $args{exclude_any_tags}; next ITEM }
                    if List::Util::Find::hasanystrs($args{exclude_any_tags}, @{ $item->{tags} // []});
                $match_a_filter++;
            }
          EXCLUDE_ALL_TAGS: {
                last unless $args{exclude_all_tags} && @{ $args{exclude_all_tags} };
                do { log_debug "Skipping item %s: does not pass exclude_all_tags %s", $item, $args{exclude_all_tags}; next ITEM }
                    if List::Util::Find::hasallstrs($args{exclude_all_tags}, @{ $item->{tags} // []});
                $match_a_filter++;
            }
          QUERY: {
                last unless $args{query} && @{ $args{query} };
                my $num_positive_queries = 0;
                my $num_negative_queries = 0;
                my $match = 0;
              Q:
                for my $query0 (@{ $args{query} }) {
                    my ($is_negative, $query) = $query0 =~ /\A(-?)(.*)/;
                    $num_positive_queries++ if !$is_negative;
                    $num_negative_queries++ if  $is_negative;

                    if (defined $item->{url}) {
                        if ($item->{url} =~ /$query/i) {
                            if ($is_negative) { goto L1 } else { $match = 1; last Q }
                        }
                    }
                    if (defined $item->{file}) {
                        if ($item->{file} =~ /$query/i) {
                            if ($is_negative) { goto L1 } else { $match = 1; last Q }
                        }
                    }
                    if (defined $item->{dir}) {
                        if ($item->{dir} =~ /$query/i) {
                            if ($is_negative) { goto L1 } else { $match = 1; last Q }
                        }
                    }
                    if (defined $item->{prog_name}) {
                        if ($item->{prog_name} =~ /$query/i) {
                            if ($is_negative) { goto L1 } else { $match = 1; last Q }
                        }
                    }
                    if (defined $item->{prog_path}) {
                        if ($item->{prog_path} =~ /$query/i) {
                            if ($is_negative) { goto L1 } else { $match = 1; last Q }
                        }
                    }
                    for my $tag (@{ $item->{tags} // [] }) {
                        if ($tag =~ /$query/i) {
                            if ($is_negative) { goto L1 } else { $match = 1; last Q }
                        }
                    }
                    if (defined $item->{firefox_container}) {
                        if ($item->{firefox_container} =~ /$query/i) {
                            if ($is_negative) { goto L1 } else { $match = 1; last Q }
                        }
                    }
                } # for query
                $match++ if $num_positive_queries == 0;
              L1:
                do { log_debug "Skipping item %s: does not pass query %s", $item, $args{query}; next ITEM }
                    unless $match;
                $match_a_filter++;
            } # QUERY
        } # FILTER

        if (!$include_by_default && !$match_a_filter) {
            log_debug "Skipping item %s: not included by default and does not match filter(s)", $item;
            next ITEM;
        }

        push @filtered_items, $item;
    } # for item

    unless ($args{detail}) {
        @filtered_items = map {
            $_->{url} // $_->{file} // $_->{dir} // $_->{prog_name} // $_->{prog_path}
        } @filtered_items;
    }

    [200, "OK", \@filtered_items];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

=head1 DESCRIPTION

This distribution includes several utilities related to L<DesktopWorkspace>:

#INSERT_EXECS_LIST


=head1 SEE ALSO

L<DesktopWorkspace>
