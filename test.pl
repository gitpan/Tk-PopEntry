use Tk;
use PopEntry;

$mw = MainWindow->new;
$pe = $mw->PopEntry(
   -maxwidth   => 6,
   -pattern    => 'float',
   -maxvalue   => '525000',
   -minvalue   => '4',
   -nospace    => 1,   
);

$pe->pack;

$label = $mw->Label(-text => "Right click somewhere in the Entry widget!");
$label->pack;

$exitbutton = $mw->Button(-text=>"Exit", -command=>sub{exit});
$exitbutton->pack;

MainLoop;