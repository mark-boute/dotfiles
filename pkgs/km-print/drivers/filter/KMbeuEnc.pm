#!/usr/bin/perl
#
# KM driver encryption module
# Version: 1.0
# August 26th 2015
# Jan Heinecke
# Filename:	KMbeuEnc.pl
#
# AES-256 CBC mode implementation is transcripted from rijndael.js
# Rijndael Reference Implementation
# Copyright (c) 2001 Fritz Schneider

package KMEncryption;

use POSIX;
use Digest::SHA qw(sha256);

my $keySizeInBits = 256;
my $blockSizeInBits = 128;

my $Nk = $keySizeInBits / 32;                   
my $Nb = $blockSizeInBits / 32;
my $Nr = $roundsArray[$Nk][$Nb];

my @roundsArray = ("","","","",["","","","",10,"",12,"",14]
                  ,"",["","","","",12,"",12,"",14]
                  ,"",["","","","",14,"",14,"",14]);
						
my @shiftOffsets = ( "","","","",["",1, 2, 3],"",["",1, 2, 3],"",["",1, 3, 4] );

my @Rcon = ( 
0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 
0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 
0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 
0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 
0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91 );

my @SBox = (
 99, 124, 119, 123, 242, 107, 111, 197,  48,   1, 103,  43, 254, 215, 171, 
118, 202, 130, 201, 125, 250,  89,  71, 240, 173, 212, 162, 175, 156, 164, 
114, 192, 183, 253, 147,  38,  54,  63, 247, 204,  52, 165, 229, 241, 113, 
216,  49,  21,   4, 199,  35, 195,  24, 150,   5, 154,   7,  18, 128, 226, 
235,  39, 178, 117,   9, 131,  44,  26,  27, 110,  90, 160,  82,  59, 214, 
179,  41, 227,  47, 132,  83, 209,   0, 237,  32, 252, 177,  91, 106, 203, 
190,  57,  74,  76,  88, 207, 208, 239, 170, 251,  67,  77,  51, 133,  69, 
249,   2, 127,  80,  60, 159, 168,  81, 163,  64, 143, 146, 157,  56, 245, 
188, 182, 218,  33,  16, 255, 243, 210, 205,  12,  19, 236,  95, 151,  68,  
23,  196, 167, 126,  61, 100,  93,  25, 115,  96, 129,  79, 220,  34,  42, 
144, 136,  70, 238, 184,  20, 222,  94,  11, 219, 224,  50,  58,  10,  73,
  6,  36,  92, 194, 211, 172,  98, 145, 149, 228, 121, 231, 200,  55, 109, 
141, 213,  78, 169, 108,  86, 244, 234, 101, 122, 174,   8, 186, 120,  37,  
 46,  28, 166, 180, 198, 232, 221, 116,  31,  75, 189, 139, 138, 112,  62, 
181, 102,  72,   3, 246,  14,  97,  53,  87, 185, 134, 193,  29, 158, 225,
248, 152,  17, 105, 217, 142, 148, 155,  30, 135, 233, 206,  85,  40, 223,
140, 161, 137,  13, 191, 230,  66, 104,  65, 153,  45,  15, 176,  84, 187,  
 22 );

sub cyclicShiftLeft {
my @theArray=@{$_[0]};
my $positions=$_[1];
  my @temp =@theArray;
  splice (@theArray, 0, $positions);
  splice (@temp , $positions, scalar(@temp));
  push (@theArray, @temp);
  return @theArray;
}

sub xtime {
  my $poly=$_[0];
  $poly <<= 1;
  return (($poly & 0x100) ? ($poly ^ 0x11B) : ($poly));		   
}

sub mult_GF256 {
  my $x=$_[0];
  my $y=$_[1];
  my $bit=0; 
  my $result = 0;
  
  for ($bit = 1; $bit < 256; $bit *= 2, $y = xtime($y) ) {
    if ($x & $bit){
      $result ^= $y;
    }
  }
  return $result;
}

sub byteSub {
  my @state=@{$_[0]};
  my $direction=$_[1];
  my @S;
  @S = @SBox;
  for (my $i = 0; $i < 4; $i++){
    for (my $j = 0; $j < $Nb; $j++){
      $state[$i][$j] = $S[$state[$i][$j]];
    }
  }
  return @state;
}

sub shiftRow {
  my @state=@{$_[0]};
  my $direction=$_[1];
  for (my $i=1; $i<4; $i++) {             
      my @temp=();
      @temp=@{$state[$i]};
      @temp=cyclicShiftLeft(\@temp, $shiftOffsets[$Nb][$i]);
      @{$state[$i]}=@temp;
  }
  return @state;
}

sub mixColumn {
  my @state=@{$_[0]};
  my $direction=$_[1];
  my @b = ();                            
  for (my $j = 0; $j < $Nb; $j++) {         
    for (my $i = 0; $i < 4; $i++) {      
        $b[$i] = mult_GF256($state[$i][$j], 2) ^        
                 mult_GF256($state[($i+1)%4][$j], 3) ^ 
                 $state[($i+2)%4][$j] ^ 
                 $state[($i+3)%4][$j];
    }
    for (my $i = 0; $i < 4; $i++) {         
      $state[$i][$j] = $b[$i];
    }
  }
  return @state;
}

sub addRoundKey {
  my @state=@{$_[0]};
  my @roundKey=@{$_[1]};
  for (my $j = 0; $j < $Nb; $j++) {                 
    $state[0][$j] ^= ($roundKey[$j] & 0xFF);         
    $state[1][$j] ^= (($roundKey[$j]>> 8) & 0xFF);
    $state[2][$j] ^= (($roundKey[$j]>> 16) & 0xFF);
    $state[3][$j] ^= (($roundKey[$j]>> 24) & 0xFF);
  }
  return @state;
}

sub keyExpansion {
  my @key=@{$_[0]};
  my @expandedKey = ();
  my $temp;
  $Nk = $keySizeInBits / 32;                   
  $Nb = $blockSizeInBits / 32;
  $Nr = $roundsArray[$Nk][$Nb];
  for (my $j=0; $j < $Nk; $j++){   
    $expandedKey[$j] = ( $key[4*$j] ) | ( $key[4*$j+1] << 8 ) | ( $key[4*$j+2] << 16 ) | ( $key[4*$j+3] << 24 );
  }
  for ($j = $Nk; $j < $Nb * ($Nr + 1); $j++) {    
    $temp = $expandedKey[$j - 1];
    if ($j % $Nk == 0){ 
      $temp = ( ( $SBox[($temp >> 8) & 0xFF] ) |
               ( $SBox[($temp >> 16) & 0xFF] << 8 ) |
               ( $SBox[($temp >> 24) & 0xFF] << 16 ) |
               ( $SBox[$temp & 0xFF] << 24 ) ) ^ $Rcon[floor($j / $Nk) - 1];
    } 
    else {
      if ($Nk > 6 && $j % $Nk == 4){ 
        $temp = ($SBox[($temp >> 24) & 0xFF] << 24) |
             ($SBox[($temp >> 16) & 0xFF] << 16) |
             ($SBox[($temp >> 8) & 0xFF] << 8) |
             ($SBox[$temp & 0xFF]);
      }       
    }
    $expandedKey[$j] = $expandedKey[$j-$Nk] ^ $temp;
  }
  return @expandedKey;
}



sub Round {
  my @state=@{$_[0]};
  my @roundKey=@{$_[1]};
  @state=byteSub(\@state, "encrypt");
  @state=shiftRow(\@state, "encrypt");
  @state=mixColumn(\@state, "encrypt");
  @state=addRoundKey(\@state, \@roundKey);
  return @state;
}

sub FinalRound {
  my @state=@{$_[0]};
  my @roundKey=@{$_[1]};
  @state=byteSub(\@state, "encrypt");
  @state=shiftRow(\@state, "encrypt");
  @state=addRoundKey(\@state, \@roundKey);
  return @state;
}

sub packBytes {
  my @octets=@{$_[0]};
  my @state =();
  if (!@octets || (scalar(@octets) % 4)){
    return;
  }
  @{$state[0]} = ();  @{$state[1]} = (); 
  @{$state[2]} = ();  @{$state[3]} = ();
  for (my $j=0; $j< (scalar(@octets)); $j+= 4) {
    $state[0][$j/4] = $octets[$j];
    $state[1][$j/4] = $octets[$j+1];
    $state[2][$j/4] = $octets[$j+2];
    $state[3][$j/4] = $octets[$j+3];
  }
  return @state;  
}

sub unpackBytes {
  my @packed=@{$_[0]};
  my @result = ();
  for (my $j=0; $j< scalar(@{$packed[0]}); $j++) {
    $result[scalar(@result)] = $packed[0][$j];
    $result[scalar(@result)] = $packed[1][$j];
    $result[scalar(@result)] = $packed[2][$j];
    $result[scalar(@result)] = $packed[3][$j];
  }
  return @result;
}

sub encrypt {
  my @block=@{$_[0]};
  my @expandedKey=@{$_[1]};
  my @tempkey=();
  my $i; 
  if (!@block || (((scalar(@block))*8) != $blockSizeInBits)){
    return; 
  }
  if (!@expandedKey){
    return;
  }
  @block = packBytes(\@block);
  @block=addRoundKey(\@block, \@expandedKey);
  for ($i=1; $i<$Nr; $i++) {
    @tempkey=@expandedKey;
    splice (@tempkey,$Nb*($i+1),scalar(@tempkey));
    splice (@tempkey,0,$Nb*$i);
    @block=Round(\@block, \@tempkey);
  }
  @tempkey=@expandedKey;	
  splice(@tempkey,0,$Nb*$Nr);	
  @block=FinalRound(\@block, \@tempkey); 
  @block=unpackBytes(\@block);
  return @block;
}

sub formatPlaintext {
  my $plaintext=$_[0];
  my $bpb = $blockSizeInBits / 8; 
  my $i;
  my @plaintextbytes=();

  if ( $plaintext=~ /^0x[0-9A-Fa-f]+$/  ){ 
    $plaintext =~ s/^0x//g;
    @plaintextbytes = map hex, unpack ("(A2)*",$plaintext);
  }
  else
  {
    for ($i=0; $i< length($plaintext); $i++){
      my @temp=split(//,$plaintext);
      $plaintextbytes[$i] = ord($temp[$i]) & 0xFF;
    }
  }
  $i = scalar(@plaintextbytes)  % $bpb;
  if ($i > 0) {
    push (@plaintextbytes, getRandomBytes($bpb - $i));
  }

  return @plaintextbytes;
}

sub getRandomBytes {
  my $howMany=$_[0];
  my $i; 
  my @bytes = ();    
  for ($i = 0; $i < $howMany; $i++) {
    $bytes[$i] = ord(chr(rand(256)));
  }
  return @bytes;
}

sub byteArrayToHex {
  my @byteArray=@{$_[0]};
  my $result = "";
  if (!@byteArray){
    return;
  }
  for (my $i=0; $i< scalar(@byteArray); $i++){
    $result = $result.sprintf("%02x",$byteArray[$i]);
  }
  $result ="0x".$result;
  return $result;
}

sub rijndaelEncrypt {
  my $plaintext=$_[0];
  my $key=$_[1];
  my $iv=$_[2];
  my @expandedKey; 
  my $i;
  my @aBlock=();
  my $bpb = $blockSizeInBits / 8;
  my @ct;
  my @keybytes=();
  my @ivbytes=();

  if ( $key=~ /^0x[0-9A-Fa-f]+$/  ){ 
    $key =~ s/^0x//g;
    @keybytes = map hex, unpack ("(A2)*",$key);
  }
  else{
    for ($i=0; $i< length($key); $i++){
      $keybytes[$i] = ord($key[$i]) & 0xFF;
    }
  }
  if (!$plaintext || !$key){
    return;
  }
  if (scalar(@keybytes)*8 != $keySizeInBits){
    return;
  }
    if ($iv=~ /^0x[0-9A-Fa-f]+$/ ){
      $iv =~ s/^0x//g;
      @ivbytes = map hex, unpack ("(A2)*",$iv);
    }
    else{
      for ($i=0; $i< length($iv); $i++){
        $ivbytes[$i] = chr($iv[$i]) & 0xFF;
      }
    }
    @ct=@ivbytes;
  my @plaintextbytes = formatPlaintext($plaintext);
  @expandedKey = keyExpansion(\@keybytes);
  for (my $block = 0; $block < scalar(@plaintextbytes) / $bpb; $block++) {
    my @tmp=();
    @tmp=@plaintextbytes;
    splice( @tmp, ($block + 1) * $bpb, scalar(@tmp));
    splice( @tmp, 0, $block * $bpb );
    @aBlock = @tmp;
      for (my $i = 0; $i < $bpb; $i++) {
        $aBlock[$i] = $aBlock[$i] ^ $ct[($block * $bpb) + $i];
      }
    @aBlock=encrypt(\@aBlock, \@expandedKey);
    push(@ct,@aBlock );
  }
    splice(@ct,0,scalar(@ivbytes));
  return @ct;
}

sub kmEncrypt{
  my $key=$_[0];
  my $pwd=$_[1];
  my @pwdbytes=();
  my @padding=();
  my @cipher;
  my $padlength= ($blockSizeInBits/8) - length($pwd) % ($blockSizeInBits/8);
  for ($i=0;$i<$padlength;$i++){
    $padding[$i]=$padlength-1;
  }
  for ($i=0; $i< length($pwd); $i++){
    my @temp=split(//,$pwd);
      $pwdbytes[$i] = ord($temp[$i]) & 0xFF;
  }
  push(@pwdbytes,@padding);

  $xplaintext=byteArrayToHex(\@pwdbytes);
  $xkey="0x".unpack("H*", sha256(substr($key,0,length($key)/2)));
  $xiv=unpack("H*", sha256(substr($key,length($key)/2,length($key)-(length($key)/2))));
  $xiv="0x".substr($xiv,0,32);
  @cipher=rijndaelEncrypt($xplaintext, $xkey,  $xiv);
  return @cipher;
}

1;

