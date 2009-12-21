use MooseX::Declare;

role CatalystX::Declare::Controller::ActionPreparation {

    use aliased 'CatalystX::Declare::Action::CatchValidationError';
    use aliased 'CatalystX::Declare::Dispatching::ChainTypeSensitivity';


    method _apply_action_roles (Object $action, @roles) {

        for my $role (CatchValidationError, @roles) {
            my $fq_role = $self->_qualify_class_name(ActionRole => $role);

            Class::MOP::load_class($fq_role);
            $fq_role->meta->apply($action);
        }
    }

    method _find_method_type_constraint (Str $name) {

        $self->meta->find_method_type_constraint($name)
            || do {
                my $method = $self->meta->find_method_by_name($name);
                    ( $_ = $method->can('type_constraint') )
                    ? $method->$_
                    : undef
            };
    }

    method _find_method_named_params (Str $name) {

        return $self->meta->find_method_named_params($name);
    }

    method _find_method_named_type_constraint (Str $method, Str $param) {

        return $self->meta->find_method_named_type_constraint($method, $param);
    }

    method _ensure_applied_dispatchtype_roles {

        my $type = $self->_app->dispatcher->dispatch_type('Chained');

        return
            if $type->DOES(ChainTypeSensitivity);

        my $immutable = $type->meta->is_immutable;
        my %immutable_options;
        if ($immutable) {
            %immutable_options = $type->meta->immutable_options;
            $type->meta->make_mutable;
        }

        # FIXME we really shouldn't have to tweak the dispatch type
        ChainTypeSensitivity->meta->apply($type->meta);

        $type->meta->make_immutable(%immutable_options)
            if $immutable;
    }

    after register_actions {

        $self->_ensure_applied_dispatchtype_roles;
    }

    around create_action (%args) {

        my @action_roles = @{ delete($args{attributes}{CatalystX_Declarative_ActionRoles}) || [] };

        my $action = $self->$orig(%args);

        return $action
            if $args{attributes}{Private};

        $self->_apply_action_roles($action, @action_roles);

        return $action 
            unless $action->DOES(CatchValidationError);

        my $tc = $self->_find_method_type_constraint($action->name);
        my $np = $self->_find_method_named_params($action->name);

        return $action
            unless $tc;

        $action->controller_instance($self);
        $action->method_type_constraint($tc);

        if ($np) {

            $action->method_named_params($np);
            $action->method_named_type_constraint({
                map +($_, $self->_find_method_named_type_constraint($action->name, $_)),
                    @$np,
            });
        }

        return $action;
    }
}
