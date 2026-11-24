-- Scyther
-- Gains 300 ATK for each Insect monster in your GY.
-- If this card is Tribute Summoned, Summoned by the activated effect of an Insect monster, or Summoned by the
-- effect of "U-Turn", it gains this effect:
-- * It can make a second attack during each Battle Phase.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(function(e) return 300*Duel.GetMatchingGroupCount(s.insect,e:GetHandlerPlayer(),LOCATION_GRAVE,0,nil) end)
	c:RegisterEffect(e1)
	-- Remember how it was Summoned
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_SUMMON_SUCCESS)
	e2:SetOperation(s.markop)
	c:RegisterEffect(e2)
	local e3=e2:Clone() e3:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e3)
	-- The second attack
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_SINGLE)
	e4:SetCode(EFFECT_EXTRA_ATTACK)
	e4:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)>0 end)
	e4:SetValue(1)
	c:RegisterEffect(e4)
end
s.listed_names={CARD_U_TURN}
function s.insect(c) return c:IsMonster() and c:IsRace(RACE_INSECT) end
function s.markop(e)
	local c=e:GetHandler()
	local ok=c:IsSummonType(SUMMON_TYPE_TRIBUTE)
	local re=c:GetReasonEffect()
	if not ok and re and c:IsSummonType(SUMMON_TYPE_SPECIAL) then
		local h=re:GetHandler()
		ok=h:IsCode(CARD_U_TURN) or (re:IsMonsterEffect() and re:IsActivated() and h:IsRace(RACE_INSECT))
	end
	if ok then c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,EFFECT_FLAG_CLIENT_HINT,1,0,aux.Stringid(id,0)) end
end
