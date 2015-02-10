public class DevManager
{
    private DumpGUI du;
    public static const int RFCOMM_TTY_MAJOR = 216;
    public static const int USB_TTY_MAJOR = 188;

    public DevManager(DumpGUI _u)
    {
        du = _u;
    }

    public void initialise_devices()
    {
        for (var i = 1; i < 10; i++)
        {
            var s = "COM%d:".printf(i);
            du.add_to_list(s, USB_TTY_MAJOR);
        }
    }
}
