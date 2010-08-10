use CatalystX::Declare;
namespace TestApp;

role hasActionParams {
    has [qw/p1 p2/] => (is=>'ro', lazy_build=>1);

    method _build_p1 {
        $self->attributes->{p1}->[0];
    }
    method _build_p2 {
        $self->attributes->{p2}->[0];
    }
}

controller ::Controller::ActionParams {

    action base
    under '/base'
    as 'actionparams';

    action first under base
    with hasActionParams(p1=>100,p2=>101) 
    is final { 
        my $p1 = $ctx->controller->action_for('first')->p1;
        my $p2 = $ctx->controller->action_for('first')->p2;
        $ctx->response->body("action_args_first: $p1,$p2");
    }

    action second under base
    with hasActionParams({p1=>200,p2=>201}) 
    is final {
        my $p1 = $ctx->controller->action_for('second')->p1;
        my $p2 = $ctx->controller->action_for('second')->p2;
        $ctx->response->body("action_args_second: $p1,$p2");
    }

}

