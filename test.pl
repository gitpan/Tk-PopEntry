use Tk;
use PopEntry;

$mw = MainWindow->new;
$pe = $mw->PopEntry;

$pe->pack;

$label = $mw->Label(-text => "Enter some text and right-click somewhere in the Entry widget!");
$label->pack;

$exitbutton = $mw->Button(-text=>"Exit", -command=>sub{exit});
$exitbutton->pack;

$pe->addItem(["Exit", 'main::exitApp', '<Control-g>', 1]);

MainLoop;

sub exitApp{ exit }
