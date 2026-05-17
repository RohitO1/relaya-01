import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.ShortBuffer;
public class Test {
    public static void main(String[] args) {
        ByteBuffer buf = ByteBuffer.allocateDirect(10);
        buf.order(ByteOrder.LITTLE_ENDIAN);
        buf.put((byte)1); buf.put((byte)2); buf.put((byte)3); buf.put((byte)4);
        
        buf.rewind();
        short[] shorts = new short[2];
        buf.asShortBuffer().get(shorts);
        shorts[0] = 99;
        
        buf.rewind();
        buf.asShortBuffer().put(shorts);
        
        buf.rewind();
        System.out.println(buf.get());
        System.out.println(buf.get());
    }
}
