package Tk::PopEntry;

$VERSION = '.04';

require Tk::Entry;

@ISA = qw(Tk::Derived Tk::Entry);

Construct Tk::Widget 'PopEntry';

sub Populate{
   my($dw, $args) = @_;
   $dw->SUPER::Populate($args);
   
   my $menuitems = delete $args->{-menuitems};
   
   if(!defined($menuitems)){
      $menuitems = [
         ["Cut",'Tk::PopEntry::moveToClip','<Control-x>',2],
         ["Copy",'Tk::PopEntry::copyToClip','<Control-c>',0],
         ["Paste",'Tk::PopEntry::pasteFromClip','<Control-v>',0],
         ["Delete",'Tk::PopEntry::deleteSelected','<Control-d>',0],
         ["Sel. All",'Tk::PopEntry::selectAll','<Control-a>',7],
      ];
   }

   $dw->ConfigSpecs(
      -pattern    => ['PASSIVE'],
      -case       => ['PASSIVE'],
      -maxwidth   => ['PASSIVE'],
      -maxvalue   => ['PASSIVE'],
      -minvalue   => ['PASSIVE'],
      -nomenu     => ['PASSIVE'],
      -nospace    => ['PASSIVE', undef, undef, 0],
      -menuitems  => ['PASSIVE', undef, undef, $menuitems],
      DEFAULT     => [$dw],
   );

   # Set default menuitems and their bindings
   $dw->setDefaultBindings;

}#END Populate()

# Override the 'insert' method based on the options supplied by the user
sub insert{
   my($dw,$index,$str) = @_;

   # Check for whitespace
   if($dw->cget(-nospace) == 1){
      if($str =~ /^\s*$/){
         $dw->bell;
         return;
      }
   }

   # Change all characters to uppercase or lowercase if appropriate
   if($dw->cget(-case) eq "upper"){ $str =~ tr/a-z/A-Z/ }
   if($dw->cget(-case) eq "lower"){ $str =~ tr/A-Z/a-z/ }

   # Save the old values before we validate
   my $oldVal = $dw->get;
   my $oldCursor = $dw->index('insert');

   # Now set insert method identical to standard Entry widget
   $dw->SUPER::insert($index,$str);

   my $newVal = $dw->get;

   # Validate the characters entered by the user as they enter them
   if(!$dw->validate($newVal)){
      $dw->delete(0,'end');
      $dw->SUPER::insert(0,$oldVal);
      $dw->icursor($oldCursor);
      $dw->bell;
   }
   else{
      my $modVal;
      if($dw->cget(-case) eq "upper"){ $modVal = uc($newVal) }
      if($dw->cget(-case) eq "lower"){ $modVal = lc($newVal) }
      if($dw->cget(-case) eq "capitalize"){ $modVal = ucfirst($newVal) }

      if( (defined($modVal)) && ($modVal ne $newVal) ){
         $oldCursor = $dw->index('insert');
         $dw->delete(0,'end');
         $dw->SUPER::insert('end',$modVal);
         $dw->icursor($oldCursor);
      }
   }
}#END insert()

sub validate{
   my($dw,$newVal) = @_;

   my($pattern, $numeric, $chars);
   my $nospace = $dw->cget(-nospace);

   if($dw->cget(-pattern) eq "unsigned_int"){
      if($nospace){ $pattern = '^\d*$' }
      else{ $pattern = '^\s*\d*\s*$' }
   }
   elsif($dw->cget(-pattern) eq "signed_int"){
      if($nospace){ $pattern = '^[\+\-]?\d*$' }
      else{ $pattern = '^\s*[\+\-]?\d*\s*$' }
   }
   elsif($dw->cget(-pattern) eq "float"){
      if($nospace){ $pattern = '^[\+\-\.]?\d*\.?\d*$' }
      else{ '^\s*[\+\-\.]?\d*\.?\d*\s*$' }
   }
   elsif($dw->cget(-pattern) eq "alpha"){
      if($nospace){ $pattern = '^[A-Za-z]*$' }
      else{ $pattern = '^\s*[A-Za-z]*\s*$' }
   }
   elsif($dw->cget(-pattern) eq "capsonly"){
      if($nospace){ $pattern = '^[A-Z]*$' }
      else{ $pattern = '^\s*[A-Z]*\s*$' }
   }
   elsif($dw->cget(-pattern) eq "nondigit"){
      if($nospace){ $pattern = '^\D*$' }
      else{ $pattern = '^\s*\D*\s*$' }
   }
   elsif($dw->cget(-pattern)){ $pattern = $dw->cget(-pattern) }

   if(defined($pattern)){
      unless($newVal =~ /$pattern/){ return }
   }
  
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # If the user specifies -maxvalue, take their word for it that they will
   # only enter numeric values.  Otherwise they'll be comparing ascii values  
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   my $maxValue = $dw->cget(-maxvalue);
   my $minValue = $dw->cget(-minvalue);

   if(defined($maxValue) && ($newVal > $maxValue)){ return 0 }
   if(defined($minValue) && ($newVal < $minValue)){ return 0 }

   my $maxLength = $dw->cget(-maxwidth);
   if(defined($maxLength) && (length($newVal) > $maxLength)){ return 0 }

   return 1;
}#END validate()

# Set the default bindings if none provided by user
sub setDefaultBindings{
   my $dw = shift;

   # Bind the right-mouse button to the pop-up menu
   $dw->bind("<Button-3>", \&popupMenu);
   $dw->bind("<Button-1>", \&popDown);
   
   $dw->bind("<Control-c>", \&copyToClip);
   $dw->bind("<Control-x>", \&moveToClip);
   $dw->bind("<Control-v>", \&pasteFromClip);
   $dw->bind("<Control-d>", \&deleteSelected);
   $dw->bind("<Control-a>", \&selectAll);

}#END setDefaultBindings()

sub popupMenu{
   my $dw = shift;

   # Don't create the menu if not desired
   if($dw->cget(-nomenu)){ return }

   # If the menu is already up,
   if(Tk::Exists($dw->{_popupMenu})){ return popDown($dw) }

   $dw->focus;
   $dw->grabGlobal;
   
   unless($dw->selectionPresent){ $dw->selectionRange(0,0) }

   my $popupMenu = $dw->Toplevel(-bd=>2, -relief=>'raised');
   $popupMenu->withdraw;
   $popupMenu->overrideredirect(1);
   $popupMenu->transient($dw);

   my $ref = $dw->cget(-menuitems);
   my($string, $callback, $binding, $index);
   
   foreach my $item(@$ref){
      $string   = $item->[0];
      $callback = $item->[1];
      $binding  = $item->[2];
      $index    = $item->[3];     
      if($string =~ /Sel.*?.All/i){
         $dw->{mb_Select} = $popupMenu->Button(
            -text       => "$string\t$binding",
            -underline  => $index,
            -command    => [$callback, $dw],
         );
      }
      else{
         $dw->{"mb_$string"} = $popupMenu->Button(
            -text       => "$string\t$binding",
            -underline  => $index,
            -command    => [$callback, $dw],
         );
      }
      $dw->bind($binding, \$callback);
      #print "\nButton is: ", $dw->{"mb_$string"} if($string =~ /exit/i);
		#$dw->bind('<Control-g>', main::exitApp);
      #print "\nBinding is: ", $binding;
   }

   # Pack the buttons and perform common configurations
   foreach my $temp(@$ref){
      my $button;
      if($temp->[0] =~ /Sel.*?.All/i){ $button = $dw->{mb_Select} }
      else{ $button = $dw->{"mb_$temp->[0]"} }
      $button->configure(-relief=>'flat', -padx=>0, -pady=>0, -anchor=>'w');
      $button->pack(-expand=>1, -fill=>'x');
      $button->bind("<Enter>", sub{
            if($_[0]->cget('-state') ne "disabled"){
               $_[0]->configure(-relief=>'raised')
            }
         }
      );
      $button->bind('<Leave>', sub{$_[0]->configure(-relief=>'flat')});
   }

   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # Enable or disable the buttons, depending on the contents of the Entry
   # widget and the clipboard and/or selection.
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   setState($dw);

   $popupMenu->geometry(sprintf("+%d+%d", $dw->rootx, $dw->rooty+20));
   $dw->grabGlobal;
   $popupMenu->deiconify;

   # Defining this now will help us later (see 'popDown' subroutine)
   $dw->{_popupMenu} = $popupMenu;

}#END popupMenu()

# Determine the various menu items should be 'normal' or 'disabled'
sub setState{
   my $dw = shift;

   my $selection = getSelection($dw, 'PRIMARY');
   my $clipboard = getSelection($dw, 'CLIPBOARD');
   my $entry = $dw->get;

   my $ref = $dw->cget(-menuitems);

   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # Set the default menu items to 'disabled', enabling them if appropriate.
   # The eval's are necessary to avoid ugly error messages if the user uses
   # a hotkey without the menu actually displayed.
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   foreach my $item(@$ref){
      if($item->[0] =~ /Cut|Copy|Paste|Delete/){
         eval{$dw->{"mb_$item->[0]"}->configure(-state=>'disabled')};
      }
      if($item->[0] =~ /Sel.*?.All/i){
         eval{$dw->{mb_Select}->configure(-state=>'disabled')};
      }
   }

   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # Only set state to 'normal' for default items if clipboard is
   # not empty or selection is present.
   #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   if(($clipboard) && ($dw->{mb_Paste})){
      eval{$dw->{mb_Paste}->configure(-state=>'normal')};
   }
   if(($selection) && ($dw->{mb_Cut})){
      eval{$dw->{mb_Cut}->configure(-state=>'normal')};
   }
   if(($selection) && ($dw->{mb_Copy})){
      eval{$dw->{mb_Copy}->configure(-state=>'normal')};
   }
   if(($selection) && ($dw->{mb_Delete})){
      eval{$dw->{mb_Delete}->configure(-state=>'normal')};
   }
   if(($entry) && ($dw->{mb_Select})){
      eval{$dw->{mb_Select}->configure(-state=>'normal')};
   }

} #END setState()

# Select all the contents of the Entry widget
sub selectAll{
   my $dw = shift;
   $dw->selectionRange(0,'end');
   setState($dw);
}

# Get the selected contents of the Entry widget
sub getSelection{
   my($dw,$selection) = @_;
   my $string;

   Tk::catch { $string = $dw->SelectionGet(-selection=>$selection) };

   $string = '' unless defined $string;
   return $string;
}

# Append data to the clipboard
sub setClip{
    my ($dw,$string) = @_;
    $dw->clipboardClear;
    $dw->clipboardAppend('--', $string);
}

# Copy data to the clipboard
sub copyToClip{
    my $dw = shift;
    if($dw->selectionPresent){ setClip($dw, getSelection($dw,'PRIMARY')) 
}
    popDown($dw);
}#END copyToClip()

# Automatically put cut or deleted data into the clipboard
sub moveToClip{
    my $dw = shift;
    if($dw->selectionPresent){ setClip($dw, deleteSelected($dw)) }
    popDown($dw);
}#END moveToClip()

# Delete selected text
sub deleteSelected{
    my $dw = shift;
    my $deleted_string;
 
    if($dw->selectionPresent){
      my $from = $dw->index('sel.first');
	   my $to = $dw->index('sel.last');
	   $deleted_string = substr($dw->get, $from, $to-$from);
	   $dw->delete($from,$to);
    }
    popDown($dw);
    return $deleted_string;
}#END deleteSelected()

# Paste data from the clipboard into the Entry widget
sub pasteFromClip{
    my $dw = shift;
    my $from = $dw->index('insert');

    if ($dw->selectionPresent){
	   $from = $dw->index('sel.first');
	   deleteSelected($dw);
    }

    $dw->insert($from,getSelection($dw,'CLIPBOARD'));
    popDown($dw);
}#END pasteFromClip()

sub popDown{
   my $dw = shift;
   if(Tk::Exists($dw->{_popupMenu})){
      $dw->{_popupMenu}->destroy;
      $dw->grabRelease;
   }
}#END popDown()


sub addItem{
	my($dw, $index, $item) = @_;

   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	# Permit the programmer to omit an index, in which case the item will be
   # added to the end of the menu.
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   if(ref($index) =~ /array/i){
		$item = $index;
		$index = 'end';
	}

	my $menu = $dw->cget(-menu);
   my $menuitems = $dw->cget(-menuitems);

   my $itemName = $item->[0];
   my $callback = $item->[1];
   my $binding  = $item->[2];
   
	my $length = scalar(@$menuitems);

   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # If an index is not supplied, the index 'end' is supplied, or the index
   # supplied is greater than the number of elements, just push the item 
   # onto the end of the menuitem array.
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   if( ($index eq 'end') || ($index > $length) ){ push(@$menuitems, $item) }

   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   # If the index *is* specified, use a temporary array to hold the removed
   # elements using splice, insert the item, then push the temporary array
   # back onto the original array.
   #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   else{
		for(my $n = 0; $n < $length + 1; $n++){
			if($index == $n){
				my @temp = splice @$menuitems, $n;
				@$menuitems[$n] = $item;
				push(@$menuitems, @temp);
			}
		}
	}	

   # Bind the item to the callback
   $dw->bind($binding, \$callback);
 
}#END addItem()

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Delete an item from the menu based on the index or index ranged passed to
# the method.  The string 'end' may also be use as a valid index.
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub deleteItem{
	my($dw,$index,$last) = @_;
   
   # Make sure an index is supplied
	if($index eq ""){ die "\nNo index supplied to 'deleteItem' method" }

   my $menuitems = $dw->cget(-menuitems);
   my $length = scalar(@$menuitems);

   # If a range of (0,'end') is detected, just configure the -nomenu option
   if( ($index == 0) && (($last eq 'end') || ($last > $length) )){
		$dw->configure(-nomenu=>1);
		return;
   }

   if($index eq 'end'){ $index = $length -1 }
	if($last eq 'end'){ $last = $length }

   # Ensure that the first index is less than the second
   if( (defined $last) && ($last < $index) ){
		die "\nThe second index must be greater than the first in 'deleteItem'";
   }

   my $numItems = $last - $index;

   # Remove a single item or group of items, as appropriate
   for(my $n = 0; $n < $length; $n++){
		if(($index == $n) && ($last eq "")){
			my $spliced = splice @$menuitems, $n, 1;
			return $spliced;
		}
		if(($index == $n) && ($last ne "")){
			my $spliced = splice @$menuitems, $n, $numItems;
			return \@spliced;
 		}
	}
}#END deleteItem()
	
1;
__END__
=head1 PopupEntry

PopupEntry - An entry widget with an automatic, configurable right-click
menu built in, plus input masks.

=head1 SYNOPSIS

  use PopupEntry
  $dw = $parent->PopupEntry(
      -pattern   => 'alpha', 'capsonly', 'signed_int', 'unsigned_int', 'float',
                 'nondigit', or any supplied regexp.
      -nomenu    => 0 or 1,
      -case      => 'upper', 'lower', 'capitalize',
      -maxwidth  => int,
      -minwidth  => int,
      -maxvalue  => int,
      -nospace   => 0 or 1,
      -menuitems => ['string', 'callback', 'binding', 'index'],
   );
   $dw->pack;
   
=head1 DESCRIPTION

PopupEntry is an Entry widget with a right-click menu automatically attached.
In addition, certain field masks can easily be applied to the entry widget in
order to force the end-user into entering only the values you want him or her
to enter.

By default, there are five items attached to the right-click menu: Cut, Copy,
Paste, Delete and Select All.  The default bindings for the items are ctrl-x,
ctrl-c, ctrl-v, ctrl-d, and ctrl-a, respectively.

The difference between 'Cut' and 'Delete' is that the former automatically
copies the contents that were cut to the clipboard, while the latter does not.

=head1 OPTIONS

-pattern
   The pattern specified here creates an input mask for the PopupEntry widget.
There are six pre-defined masks:
alpha - Upper and lower case a-z only.
capsonly - Upper case A-Z only.
nondigit - Any characters except 0-9.
float - A float value, which may or may not include a decimal.
signed_int - A signed integer value, which may or may not include a '+'.
unsigned_int - An unsigned integer value.

You may also specify a regular expression of your own design using Perl's
standard regular expression mechanisms.  Be sure to use single quotes.

-nomenu
   If set to true, then no right-click menu will appear.  Presumably, you would
set this if you were only interested in the input-mask functionality.

-nospace
   If set to true, the user may not enter whitespace before, after or between
words within that PopupEntry widget.

-maxwidth
   Specifies the maximum number of characters that the user can enter in that
particular PopupEntry widget.  Note that this is not the same as the width
of the widget.

-maxvalue
   If one of the pre-defined numeric patterns is chosen, this specifies the
maximum allowable value that may be entered by a user for the widget.

-minvalue
   If one of the pre-defined numeric patterns is chosen, this specifies the
minimum allowable value for the first digit (0-9).  This should work better.

-menuitems
   If specified, this creates a user-defined right-click menu rather than
the one that is provided by default.  The value specified must be a four
element nested anonymous array that contains: 

a string that appears on the menu,
a callback (in 'package::callback' syntax format), 
a binding for that option (see below), 
and an index value specifying where on the menu it should appear,  starting at 
index 0.

   The binding specified need only be in the form, '<ctrl-x>'.  You needn't
explicitly bind it yourself.  Your callback will automatically be bound to
the event sequence you specified.
   
=head1 KNOWN BUGS

The -pattern option "capsonly" will only work properly if no more than one 
word is supplied.

The -minvalue only works for the first digit.

=head1 PLANNED CHANGES

Fix the issues mentioned above.

Allow individual entries to be added or removed from the menu via predefined
methods.

=head1 AUTHOR

Daniel J. Berger
djberg96@hotmail.com

=head1 SEE ALSO

Entry

=cut
