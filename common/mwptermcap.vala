public class  MwpTermCap : Object
{
    public static string ceol;
    public static string civis;
    public static string cnorm;
    private static char tbuf[1024];

    public static void init()
    {
        if(1 == Tc.tgetent(tbuf, Environment.get_variable("TERM").data))
        {
            char buf[64];
            char *pbuf = buf;
            unowned string s;
            s = Tc.tgetstr("ce", &pbuf);
            ceol = (s == null) ? "" : s.dup();

            s = Tc.tgetstr("vi", &pbuf);
            civis = (s == null) ? "" : s.dup();

            s = Tc.tgetstr("ve", &pbuf);
            cnorm = (s == null) ? "" : s.dup();
        }
    }

/*
 * well **** me, here we are in 2018, using terminal escape sequecences
 * like it's 1981. This is outrageous.
 */

}
