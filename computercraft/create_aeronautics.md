
Analog transmission:
```java
public float getRotationModifier() {
        return 1 - (this.signal + 1) / 16f;
    }
```
so analog transmission lerps from 0, 1/16, 2/16, 3/16, as the signal goes from full.
this can be used with (distance) modulating linked receiver to keep a (16-step) constant r*\theta


directional linked receiver
```java
(int) Math.min((29 / Math.PI) * angle + 1, transmittedStrength)
```



idea about a puzzle where you need to utilize a computer to automate a task.
you need to predict a pattern. the pattern is really simple, but very difficult to automate with just redstone.
maybe you need to input the fibonacci sequence


$$\Sigma$$


# matrices

col is the input dimension, row the output dimension:  
A(x: R^col) : R^row


```
            . t r i
            c . . .
            o . . .
            l . . .

 . c o l    . t r i 
 r . . .    r . . .
 o . . .    o . . .
 w . . .    w . . .
 . . . .    . . . .


        X
        Y
        Z
A B C   AX+BY+CZ


```

W^(col,row): X^col -> X^row

a bit confusing: a column vector is a matrix with one column


$$ 
\newcommand{\inner}[2]{\langle {#1} | {#2} \rangle}
\newcommand{\for}[2]{^{\left({#1}\right)\rightarrow}{#2}}
\for{x}{x^2}
\\
\text{oh hey, I just realized, the function} \lambda x.fx 
\text{ is of type} \forall X.Y

$$

$$
\phantom {xyz} \\

\\.\r{.\r{.\r.}}.\\

\begin{align*}
&
\bra{a} \text{is a row vector} 
\left[\begin{matrix} 1 & 2 & 3 & 4 \end{matrix}\right]  
\\&
\ket{b} \text{is a column vector} 
\left[\begin{matrix} 1 \\ 2 \\ 3 \\ 4 \end{matrix}\right] 
\\&\\&
\\&
\bra a \ket a = \inner{a}{a} & \in \R
\\&
\ket b \bra a \ket a = \ket b \inner{a}{a} & \in \ket b \R
\\&
\text{a matrix is a linear combination of } \for{x,y}{\ket{y}\bra{x}}




\end{align*}
$$



```

<a| |b> : 1
|b><c| : |> --> |>


```

arbitrary-shape matrices don't form a ring, but the set can be partitioned according to shape,
same-shape matrices form an additive group. in addition <A,B> * <B,C> = <A,C> is a partial multiplication that is bilinear
see Category of Matrices

hm, what if the field was also like this? a collection of groups with partial multiplications, 
and X<A,B> * Y<B,C> is only defined if X * Y is defined



idea: a set of groups