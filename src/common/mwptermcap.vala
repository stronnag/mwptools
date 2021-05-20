public class  MwpTermCap : Object
{
    public static string ceol;
    public static string civis;
    public static string cnorm;
#if USE_TERMCAP
    private static char tbuf[1024];
#endif

    public static void init()
    {
        cnorm = civis = "";
        ceol="   ";
#if USE_TERMCAP
        if(1 == Tc.tgetent(tbuf, Environment.get_variable("TERM").data))
        {
            char buf[64];
            char *pbuf = buf;
            unowned string s;
            if((s = Tc.tgetstr("ce", &pbuf)) != null)
                ceol = s.dup();

            if((s = Tc.tgetstr("vi", &pbuf)) != null)
                civis = s.dup();

            if((s = Tc.tgetstr("ve", &pbuf)) != null)
                cnorm = s.dup();
        }
#endif
    }
}
