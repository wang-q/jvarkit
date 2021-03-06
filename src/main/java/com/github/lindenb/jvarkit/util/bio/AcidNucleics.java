package com.github.lindenb.jvarkit.util.bio;



public class AcidNucleics {

	
public static String reverseComplement(CharSequence seq)
	{
	StringBuilder b=new StringBuilder(seq.length());
	for(int i=0;i< seq.length();++i)
		{
		b.append(complement(seq.charAt((seq.length()-1)-i)));
		}
	return b.toString();
	}
	
public static char complement(char c)
	{
	switch(c)
		{
        case 'A': return 'T';
        case 'T': case 'U': return 'A';
        case 'G': return 'C';
        case 'C': return 'G';

        case 'a': return 't';
        case 't': case 'u': return 'a';
        case 'g': return 'c';
        case 'c': return 'g';

        case 'w': return 'w';
        case 'W': return 'W';

        case 's': return 's';
        case 'S': return 'S';

        case 'y': return 'r';
        case 'Y': return 'R';

        case 'r': return 'y';
        case 'R': return 'Y';

        case 'k': return 'm';
        case 'K': return 'M';

        case 'm': return 'k';
        case 'M': return 'K';

        case 'b': return 'v';
        case 'd': return 'h';
        case 'h': return 'd';
        case 'v': return 'b';


        case 'B': return 'V';
        case 'D': return 'H';
        case 'H': return 'D';
        case 'V': return 'B';

        case 'N': return 'N';
        case 'n': return 'n';
		default: return 'N';
		}
	}

/** return the 'weight' of a degenerate base e.g: A=1, N=0, W=0.5, B=0.25, used with restriction enzymes */
public static float weight(char c)
	{
	switch(c)
		{
        case 'A': 
        case 'T':
        case 'U': 
        case 'G': 
        case 'C': 
        case 'a':
        case 't':
        case 'u': 
        case 'g': 
        case 'c': return 1f;

        case 'w': 
        case 'W': 

        case 's': 
        case 'S': 

        case 'y': 
        case 'Y': 

        case 'r': 
        case 'R':

        case 'k':
        case 'K': 

        case 'm': 
        case 'M': return 0.5f;

        case 'b': 
        case 'd': 
        case 'h': 
        case 'v': 
        case 'B': 
        case 'D': 
        case 'H': 
        case 'V': return 0.25f;

        case 'N':
        case 'n':
		default: return 0.f;
		}
	}

}
