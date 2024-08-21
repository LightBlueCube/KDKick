untyped
global function KDKick_Init

array<string> KickedPlayerArray = []    //保存被封禁的玩家的数组，下局清零，不需要动

table<string,int> PlayerKill = {}    //让我们使用table来存储玩家击杀数据！（玩家退出后不消失！）
table<string,int> PlayerDeath = {}   //让我们使用table来存储玩家死亡数据！（玩家退出后不消失！）

array<int> kick_k = []
array<float> kick_kd = []
/*
让我来解释一下这个东西怎么填
以下，我会简称击杀次数为k，死亡次数为d
当玩家k低于于kick_k内的第一个数时
如果他的kd比达到了kick_kd的第一个数
那么服务器会踢出他，本对局封禁
当玩家k小于Kick_k内的第二个数但又大于第一个数时
如果他的kd比达到了kick_kd的第二个数
那么服务器会踢出他，本对局封禁

举例
我希望我服务器内的老毕等
在30杀以下kd比高于2就踢出
过了30杀但是不到60杀的时候kd比高于1.5就踢出
过了60杀的时候kd比高于1就踢出
那么这样填

array<int> kick_k = [ 30, 60 ]
array<float> kick_kd = [ 2.0, 1.5, 1.0 ]

举例
我希望我服务器内的老毕等kd比大于1就踢出
那么这样填

array<int> kick_k = []
array<float> kick_kd = [ 1.0 ]

*/


void function KDKick_Init()
{
    kick_k.append( 999 )  //给击杀检测阈值增加一个上限
    AddCallback_OnPlayerKilled( OnPlayerKilled )
    AddCallback_OnClientConnected( OnClientConnected )
    AddCallback_OnPlayerRespawned( OnPlayerRespawned )
}

void function OnPlayerRespawned( entity player )        //当玩家复活时
{
    if( KickedPlayerArray.contains( player.GetUID() ) ) //如果数组内包含玩家的uid（那么就代表本对局已经封禁这位玩家）
        ServerCommand( "kickid "+ player.GetUID() )         //直接给他踢了
}

void function OnClientConnected( entity player )    //当玩家连接到服务器时，初始化他的k(击杀次数)和d(死亡次数)
{
    if( player.GetUID() in PlayerKill && player.GetUID() in PlayerDeath )   //如果玩家的数据已经被初始化过
        return                                                              //不做操作以免重置玩家k和d

    //在这里负责初始化！
    PlayerKill[ player.GetUID() ] <- 0
    PlayerDeath[ player.GetUID() ] <- 0
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )  //当玩家击杀时
{
    if( !IsValid( attacker ) || !IsValid( victim ) )        //如果玩家不可用（例如掉线，或者别的什么）
        return                                                  //直接结束，此次击杀不做任何操作
    if( attacker.GetTeam() == victim.GetTeam() )            //如果攻击者和受害者属于一个阵营，判断为紫砂或者卡bug击杀队友
        return                                                  //直接结束，此次击杀不做任何操作
    if( !attacker.IsPlayer() || !victim.IsPlayer() )        //如果攻击者或受害者是NPC，判断为ai击杀或者击杀ai
        return                                                  //同样的，我们也直接结束，此次击杀不做任何操作

    PlayerKill[ attacker.GetUID() ] += 1       //攻击者的k(击杀次数)增加1点
    PlayerDeath[ victim.GetUID() ] += 1        //受害者的d(死亡次数)增加一点

    int k = PlayerKill[ attacker.GetUID() ]    //把攻击者的击杀次数存到名字为k的变量里
    int d = PlayerDeath[ attacker.GetUID() ]   //把攻击者的死亡次数存到名字为d的变量里
    float kd = float( k ) / float( d )         //获取kd比
    if( d == 0 )                    //如果死亡次数为0，很明显直接去算kd比的话会出现除以0的情况，那我们在这里检测一下
        kd = float( k )             //如果确实为0，那么直接使用击杀次数作为kd比
    int i = 0                       //定义一个数，一会循环内使用它来读取踢出阈值的两个数组

    for( ;; )   //开始循环
    {
        if( i == kick_k.len() )     //如果读完了
            return                  //终止操作（读完意味着没有发现符合踢出条件）

        if( k <= kick_k[i] )        //如果玩家击杀小于kick_k的第i个数
        {
            if( kd > kick_kd[i] )   //如果玩家kd比大于kick_kd的第i个数
                break               //踢出条件符合，打破循环

            return                  //玩家的击杀没达到第i个阈值，我们不应该检查下一个阈值，在这终止操作
        }

        i++                         //踢出条件不符合，对变量i做+1操作，接着读踢出阈值数组的下一个数
    }

    thread BanPlayerInThisMatch_Threaded( attacker )      //符合条件，给他踢了，转到下面的在本对局封禁该玩家
}

void function BanPlayerInThisMatch_Threaded( entity player ) //在本对局封禁该玩家
{
    KickedPlayerArray.append( player.GetUID() ) //将玩家的UID存入数组，这个数组会在玩家重生的时候被调用
    if( IsAlive( player ) )                     //如果玩家活着
        player.Die()                                //我们就把他杀了，这样可以让后续的踢出提示更加显眼

    SendHudMessage( player, "喜报！\n你的KD过高！即将被踢出", -1, 0.4, 255, 0, 0, 255, 0.15, 5, 1 )     //给将要被踢出老东西的屏幕上发送文字
    wait 4                          //给他四秒的时间看文字
    if( !IsValid( player ) )        //如果玩家不可用（比方说他看到消息提前退了）
        return                          //终止操作（反正uid已经存入数组，他回不来了）

    ServerCommand( "kickid "+ player.GetUID() )     //如果没有出现任何问题，那么踢掉老东西
}