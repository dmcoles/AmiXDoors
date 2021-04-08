  OPT MODULE,REG=5

PROC func0(abcd:PTR TO LONG) IS (abcd[1] AND abcd[2]) OR (Not(abcd[1]) AND abcd[3])

PROC func1(abcd:PTR TO LONG) IS (abcd[3] AND abcd[1]) OR (Not(abcd[3]) AND abcd[2])

PROC func2(abcd:PTR TO LONG) IS Eor(Eor(abcd[1],abcd[2]),abcd[3])

PROC func3(abcd:PTR TO LONG) IS Eor(abcd[2],abcd[1] OR (Not(abcd[3])))

PROC rol(r,n)
  MOVE.L r,D0
  MOVE.L n,D1
  ROL.L D1,D0
ENDPROC D0

PROC endianswitch(n)
  DEF n2
  n2:=Shl(n AND $FF,24) OR Shl(n AND $FF00,8) OR Shr(n AND $FF0000,8) OR (Shr(n AND $FF000000,24) AND $FF)
ENDPROC n2

PROC hash_MD5(h:PTR TO LONG, k:PTR TO LONG,msg:PTR TO CHAR, mlen)
  DEF h0:PTR TO LONG
  DEF ff:PTR TO LONG
  DEF m:PTR TO INT
  DEF o:PTR TO INT
  DEF rot0:PTR TO INT
  DEF rot1:PTR TO INT
  DEF rot2:PTR TO INT
  DEF rot3:PTR TO INT
  DEF rots:PTR TO LONG
  
  DEF abcd[4]:ARRAY OF LONG
  DEF fctn[4]:ARRAY OF LONG
  DEF m_,o_,g
  DEF f
  DEF rotn:PTR TO INT
  DEF mm[16]:ARRAY OF LONG
  DEF os=0
  DEF grp,grps,q,p
  DEF msg2:PTR TO CHAR
  DEF u:LONG
  DEF d
  
  h0:=[$67452301, $EFCDAB89, $98BADCFE, $10325476]:LONG
  ff:=[{func0},{func1},{func2},{func3}]:LONG
  m:=[1,5,3,7]:INT
  o:=[0,1,5,0]:INT
  rot0:=[7,12,17,22]:INT
  rot1:=[5,9,14,20]:INT
  rot2:=[4,11,16,23]:INT
  rot3:=[6,10,15,21]:INT
  rots:=[rot0,rot1,rot2,rot3]:LONG
 
  FOR q:=0 TO 3 DO h[q]:=h0[q]
  
  grps:=1+Shr((mlen+8),6)
  msg2:=New(Shl(grps,6))
  CopyMem(msg,msg2,mlen)
  msg2[mlen]:=$80
  q:=mlen+1
  WHILE (q < Shl(grps,6))
    msg2[q]:=0
    q++
  ENDWHILE
  
  u:=endianswitch(Shl(mlen,3))
  q:=q-8
  CopyMem({u},msg2+q,4)
  
  FOR grp:=0 TO grps-1
    CopyMem(msg2+os,mm,64)

		FOR q:=0 TO 3 DO abcd[q]:=h[q]
    
		FOR p:=0 TO 3
			fctn:=ff[p]
			rotn:=rots[p]
			m_:=m[p]
      o_:=o[p]
			FOR q:=0 TO 15
				g:= ((Mul(m_,q) + o_) AND 15)
        
        d:=fctn(abcd)
				f:=abcd[1]+rol(abcd[0] + d + k[q + Shl(p,4)] + endianswitch(mm[g]), rotn[q AND 3])

				abcd[0]:=abcd[3]  -> A = dtemp
				abcd[3]:=abcd[2]  -> D = C
				abcd[2]:=abcd[1]  -> C = B
				abcd[1]:=f        -> B = B + rotate(a+f+k(i)+m(j),s(i)
			ENDFOR
		ENDFOR
		FOR p:=0 TO 3 DO h[p]:=h[p]+abcd[p]
		os:=os+64
	ENDFOR
  Dispose(msg2)
 
ENDPROC

EXPORT PROC getMD5string(msg:PTR TO CHAR,outstr:PTR TO CHAR)
  DEF j
  DEF u
  DEF s[8]:STRING
  DEF h[4]:ARRAY OF LONG
  DEF b:PTR TO CHAR

  StrCopy(outstr,'')
  hash_MD5(h,{kspace},msg, StrLen(msg))
  
  FOR j:=0 TO 3
    StringF(s,'\z\h[8]',endianswitch(h[j]))
    StrAdd(outstr,s)
  ENDFOR
  
ENDPROC

kspace:
     LONG  $d76aa478, $e8c7b756, $242070db, $c1bdceee,
     $f57c0faf, $4787c62a, $a8304613, $fd469501 ,
     $698098d8, $8b44f7af, $ffff5bb1, $895cd7be ,
     $6b901122, $fd987193, $a679438e, $49b40821 ,
     $f61e2562, $c040b340, $265e5a51, $e9b6c7aa ,
     $d62f105d, $02441453, $d8a1e681, $e7d3fbc8 ,
     $21e1cde6, $c33707d6, $f4d50d87, $455a14ed ,
     $a9e3e905, $fcefa3f8, $676f02d9, $8d2a4c8a ,
     $fffa3942, $8771f681, $6d9d6122, $fde5380c ,
     $a4beea44, $4bdecfa9, $f6bb4b60, $bebfbc70 ,
     $289b7ec6, $eaa127fa, $d4ef3085, $04881d05 ,
     $d9d4d039, $e6db99e5, $1fa27cf8, $c4ac5665 ,
     $f4292244, $432aff97, $ab9423a7, $fc93a039 ,
     $655b59c3, $8f0ccc92, $ffeff47d, $85845dd1 ,
     $6fa87e4f, $fe2ce6e0, $a3014314, $4e0811a1 ,
     $f7537e82, $bd3af235, $2ad7d2bb, $eb86d391